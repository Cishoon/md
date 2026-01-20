# md installer for PowerShell

$InstallDir = Join-Path $env:LOCALAPPDATA "md"
$ScriptPath = Join-Path $InstallDir "md.ps1"
$ProfilePath = $PROFILE.CurrentUserAllHosts

function Install-Md {
    Write-Host "Installing md..."
    
    # Create install directory
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    
    # Copy script
    $ScriptDir = Split-Path -Parent $MyInvocation.ScriptName
    Copy-Item (Join-Path $ScriptDir "md.ps1") $ScriptPath -Force
    
    # Ensure profile exists
    if (-not (Test-Path $ProfilePath)) {
        New-Item -ItemType File -Force -Path $ProfilePath | Out-Null
    }
    
    # Add to profile if not already there
    $ProfileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
    if ($ProfileContent -notmatch "md\\md\.ps1") {
        Add-Content $ProfilePath "`n# md - copy last command to clipboard`n. `"$ScriptPath`""
        Write-Host "Added to $ProfilePath"
    } else {
        Write-Host "md already configured in profile"
    }
    
    Write-Host ""
    Write-Host "Done!"
    Write-Host ""
    Write-Host "Restart PowerShell or run: . `$PROFILE"
}

function Uninstall-Md {
    Write-Host "Uninstalling md..."
    
    # Remove from profile
    if (Test-Path $ProfilePath) {
        $content = Get-Content $ProfilePath | Where-Object { $_ -notmatch "md" }
        $content | Set-Content $ProfilePath
        Write-Host "Removed from profile"
    }
    
    # Remove install directory
    if (Test-Path $InstallDir) {
        Remove-Item -Recurse -Force $InstallDir
        Write-Host "Removed $InstallDir"
    }
    
    Write-Host ""
    Write-Host "Done! Restart PowerShell."
}

# Main
if ($args[0] -eq "uninstall") {
    Uninstall-Md
} else {
    Install-Md
}
