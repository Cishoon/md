# md online installer for PowerShell
# Usage: irm https://raw.githubusercontent.com/Cishoon/md/main/install-online.ps1 | iex

$Repo = "Cishoon/md"
$RawUrl = "https://raw.githubusercontent.com/$Repo/main"
$InstallDir = Join-Path $env:LOCALAPPDATA "md"
$ScriptPath = Join-Path $InstallDir "md.ps1"
$ProfilePath = $PROFILE.CurrentUserAllHosts

Write-Host "Installing md..."

# Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Download script
Invoke-WebRequest -Uri "$RawUrl/md.ps1" -OutFile $ScriptPath

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
    Write-Host "md already configured"
}

Write-Host ""
Write-Host "Done!"
Write-Host ""
Write-Host "Restart PowerShell or run: . `$PROFILE"
