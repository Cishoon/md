# md.ps1 - copy last command and output to clipboard (PowerShell 5.1/7+)

if (-not $Host.UI.RawUI) { return }
if (-not (Get-Module -ListAvailable PSReadLine)) { return }

$global:MD_DIR = Join-Path $env:LOCALAPPDATA "md"
New-Item -ItemType Directory -Force -Path $global:MD_DIR | Out-Null
$global:MD_LOG = Join-Path $global:MD_DIR ("{0}.transcript.txt" -f $PID)
$global:MD_META = Join-Path $global:MD_DIR ("{0}.meta.json" -f $PID)

# Start transcript once per session
if (-not $global:MD_ENABLED) {
    $global:MD_ENABLED = $true
    try { Start-Transcript -Path $global:MD_LOG -Append | Out-Null } catch {}
}

function global:__md_get_len {
    try { (Get-Item -LiteralPath $global:MD_LOG).Length } catch { 0 }
}

# Pre-command hook
Set-PSReadLineOption -CommandValidationHandler {
    param([string]$command)
    $global:__md_start = __md_get_len
    $global:__md_cmd = $command
}

# Preserve original prompt
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

function global:md {
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
    
    # Read exact byte range
    $fs = [System.IO.File]::Open($m.log, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $fs.Seek($start, [System.IO.SeekOrigin]::Begin) | Out-Null
        $buf = New-Object byte[] $count
        $read = $fs.Read($buf, 0, $buf.Length)
        
        # Try UTF-16LE first (Windows transcript), fallback UTF-8
        $text = [System.Text.Encoding]::Unicode.GetString($buf, 0, $read)
        if ($text -match "\x00") {
            $text = [System.Text.Encoding]::UTF8.GetString($buf, 0, $read)
        }
        
        # Build output
        $output = "$ $($m.cmd)`n$text"
        
        # Copy to clipboard using OSC 52
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($output))
        [Console]::Write("`e]52;c;$encoded`a")
        
        Write-Host "copied"
    } finally {
        $fs.Dispose()
    }
}
