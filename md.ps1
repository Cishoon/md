# md.ps1 - copy last command and output to clipboard (PowerShell 5.1/7+)

$global:MD_VERSION = "1.1.0"
$global:MD_REPO = "Cishoon/md"
$global:MD_RAW_URL = "https://raw.githubusercontent.com/$global:MD_REPO/main"

if (-not $Host.UI.RawUI) { return }
if (-not (Get-Module -ListAvailable PSReadLine)) { return }

$global:MD_DIR = Join-Path $env:LOCALAPPDATA "md"
New-Item -ItemType Directory -Force -Path $global:MD_DIR | Out-Null
$global:MD_LOG = Join-Path $global:MD_DIR ("{0}.transcript.txt" -f $PID)
$global:MD_META = Join-Path $global:MD_DIR ("{0}.meta.json" -f $PID)
$global:MD_UPDATE_CHECK = Join-Path $global:MD_DIR ".last_update_check"

if (-not $global:MD_ENABLED) {
    $global:MD_ENABLED = $true
    try { Start-Transcript -Path $global:MD_LOG -Append | Out-Null } catch {}
}

function global:__md_get_len {
    try { (Get-Item -LiteralPath $global:MD_LOG).Length } catch { 0 }
}

Set-PSReadLineOption -CommandValidationHandler {
    param([string]$command)
    $global:__md_start = __md_get_len
    $global:__md_cmd = $command
}

if (-not $global:__md_orig_prompt) {
    $global:__md_orig_prompt = $function:prompt
}

function global:prompt {
    $rc = if ($null -ne $global:LASTEXITCODE) { $global:LASTEXITCODE } else { 0 }
    $end = __md_get_len
    $start = if ($null -ne $global:__md_start) { [int64]$global:__md_start } else { $end }
    
    $meta = [ordered]@{
        start = $start
        end   = $end
        rc    = $rc
        cmd   = $global:__md_cmd
        log   = $global:MD_LOG
    } | ConvertTo-Json -Depth 4
    
    try { $meta | Set-Content -LiteralPath $global:MD_META -Encoding UTF8 } catch {}
    
    & $global:__md_orig_prompt
}

function global:__md_check_update {
    $today = (Get-Date).ToString("yyyy-MM-dd")
    $lastCheck = ""
    if (Test-Path $global:MD_UPDATE_CHECK) {
        $lastCheck = Get-Content $global:MD_UPDATE_CHECK -ErrorAction SilentlyContinue
    }
    
    if ($lastCheck -eq $today) { return }
    
    $today | Set-Content $global:MD_UPDATE_CHECK
    
    try {
        $remote = Invoke-WebRequest -Uri "$global:MD_RAW_URL/md.ps1" -TimeoutSec 2 -ErrorAction Stop
        if ($remote.Content -match 'MD_VERSION\s*=\s*"([^"]+)"') {
            $remoteVersion = $matches[1]
            if ($remoteVersion -ne $global:MD_VERSION) {
                Write-Host "md: new version available ($global:MD_VERSION -> $remoteVersion)"
                Write-Host "    run 'md update' to upgrade"
            }
        }
    } catch {}
}

function global:__md_update {
    Write-Host "Updating md..."
    $scriptPath = Join-Path $global:MD_DIR "md.ps1"
    try {
        Invoke-WebRequest -Uri "$global:MD_RAW_URL/md.ps1" -OutFile $scriptPath
        Write-Host "Updated. Restart PowerShell or run: . `$PROFILE"
    } catch {
        Write-Error "Update failed: $_"
    }
}

function global:__md_uninstall {
    Write-Host "Uninstalling md..."
    
    $profilePath = $PROFILE.CurrentUserAllHosts
    if (Test-Path $profilePath) {
        $content = Get-Content $profilePath | Where-Object { $_ -notmatch "md" }
        $content | Set-Content $profilePath
    }
    
    Remove-Item -Recurse -Force $global:MD_DIR -ErrorAction SilentlyContinue
    
    Write-Host "Done. Restart PowerShell."
}

function global:md {
    param([string]$Command)
    
    switch ($Command) {
        "update" {
            __md_update
            return
        }
        "uninstall" {
            __md_uninstall
            return
        }
        { $_ -in "version", "-v", "--version" } {
            Write-Host "md $global:MD_VERSION"
            return
        }
        { $_ -in "help", "-h", "--help" } {
            Write-Host "md - copy last command and output to clipboard"
            Write-Host ""
            Write-Host "Usage:"
            Write-Host "  md            copy last command to clipboard"
            Write-Host "  md update     update to latest version"
            Write-Host "  md uninstall  remove md"
            Write-Host "  md version    show version"
            return
        }
    }
    
    if (-not (Test-Path -LiteralPath $global:MD_META)) {
        Write-Error "no record"
        return
    }
    
    $m = Get-Content -LiteralPath $global:MD_META -Raw | ConvertFrom-Json
    $start = [int64]$m.start
    $count = [int64]($m.end - $m.start)
    
    if ($count -lt 0) {
        Write-Error "bad offsets"
        return
    }
    
    $fs = [System.IO.File]::Open($m.log, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $fs.Seek($start, [System.IO.SeekOrigin]::Begin) | Out-Null
        $buf = New-Object byte[] $count
        $read = $fs.Read($buf, 0, $buf.Length)
        
        $text = [System.Text.Encoding]::Unicode.GetString($buf, 0, $read)
        if ($text -match "\x00") {
            $text = [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
        }
        
        $output = "$ $($m.cmd)`n$text"
        
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($output))
        [Console]::Write("`e]52;c;$encoded`a")
        
        Write-Host "copied"
    } finally {
        $fs.Dispose()
    }
}

# Check for updates daily (background)
Start-Job -ScriptBlock { __md_check_update } -ErrorAction SilentlyContinue | Out-Null
