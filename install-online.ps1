# md online installer for PowerShell
# Usage: irm https://raw.githubusercontent.com/Cishoon/md/main/install-online.ps1 | iex
# Or:    $env:MD_CMD_NAME = "mdd"; irm https://raw.githubusercontent.com/Cishoon/md/main/install-online.ps1 | iex

$ErrorActionPreference = "Stop"

$REPO = "Cishoon/md"
$INSTALL_DIR = Join-Path $HOME ".md"
$RAW_URL = "https://raw.githubusercontent.com/$REPO/main"

# Use MD_CMD_NAME env var if set, otherwise default to "md"
$CMD_NAME = if ($env:MD_CMD_NAME) { $env:MD_CMD_NAME } else { "md" }

function Main {
    Write-Host "Installing md (command: $CMD_NAME)..."
    Write-Host ""
    
    # 创建安装目录
    if (-not (Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
    }
    
    # 下载脚本
    $mdPath = Join-Path $INSTALL_DIR "md.ps1"
    Write-Host "Downloading md.ps1..."
    Invoke-WebRequest -Uri "$RAW_URL/md.ps1" -OutFile $mdPath -UseBasicParsing
    
    # 确保 $PROFILE 目录存在
    $profileDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    # 确保 $PROFILE 文件存在
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    }
    
    # 检查是否已配置
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($profileContent -and $profileContent -match '\.md[/\\]md\.ps1') {
        Write-Host "md already configured in `$PROFILE"
    } else {
        # 添加到 $PROFILE
        $loadScript = @"

# md - copy last command to clipboard
`$env:MD_CMD_NAME = "$CMD_NAME"
. "`$HOME\.md\md.ps1"
"@
        Add-Content -Path $PROFILE -Value $loadScript
        Write-Host "Added to $PROFILE"
    }
    
    Write-Host ""
    Write-Host "Done!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run: . `$PROFILE"
    Write-Host "Then type any command, and use '$CMD_NAME' to copy it."
    
    if ($CMD_NAME -eq "md") {
        Write-Host ""
        Write-Host "Note: This will override the built-in 'md' alias (mkdir)." -ForegroundColor Yellow
        Write-Host "      Use 'mkdir' or 'New-Item' for creating directories." -ForegroundColor Yellow
    }
}

Main
