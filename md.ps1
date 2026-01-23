# md - copy last command and output to clipboard (PowerShell version)
# 需要在 $PROFILE 中 dot-source 此文件: . ~/.md/md.ps1

$script:MD_VERSION = "1.4.0"
$script:MD_REPO = "Cishoon/md"
$script:MD_RAW_URL = "https://raw.githubusercontent.com/$MD_REPO/main"
$script:MD_DIR = Join-Path $HOME ".md"
$script:MD_FILE = Join-Path $env:TEMP ".md_output_$PID.log"
$script:MD_UPDATE_CHECK = Join-Path $MD_DIR ".last_update_check"
$script:MD_EXCLUDE_FILE = Join-Path $MD_DIR "exclude"
$script:MD_TRANSCRIPT_FILE = Join-Path $env:TEMP ".md_transcript_$PID.log"
$script:_MD_MAX_SIZE = 32 * 1024 * 1024

# 默认排除列表（仅交互式命令）
$script:_MD_DEFAULT_EXCLUDE = @(
    'md', 'mdd', 'clear', 'cls', 'reset', 'exit',
    'vim', 'vi', 'nano', 'less', 'more', 'top', 'htop', 'man',
    'ssh', 'nload', 'iftop', 'watch', 'tmux', 'screen',
    'emacs', 'nvim', 'mc', 'ranger', 'lazygit', 'tig', 'fzf',
    'ls', 'll'
)

# 状态变量
$script:_MD_INIT = $false
$script:_MD_LAST_CMD = ""
$script:_MD_CURRENT_CMD = ""
$script:_MD_START_OFFSET = 0
$script:_MD_LAST_END_OFFSET = 0
$script:_MD_EXCLUDE_PATTERN = $null
$script:_MD_ORIGINAL_PROMPT = $null

# 构建排除正则
function script:_md_build_exclude {
    $excludeList = [System.Collections.ArrayList]::new($script:_MD_DEFAULT_EXCLUDE)
    
    if (Test-Path $script:MD_EXCLUDE_FILE) {
        $userExclude = Get-Content $script:MD_EXCLUDE_FILE -ErrorAction SilentlyContinue |
            Where-Object { $_ -and $_ -notmatch '^\s*#' }
        if ($userExclude) {
            $excludeList.AddRange(@($userExclude))
        }
    }
    
    # 构建正则：匹配命令开头
    $escaped = $excludeList | ForEach-Object { [regex]::Escape($_) }
    $script:_MD_EXCLUDE_PATTERN = "^\s*($($escaped -join '|'))(\s|$)"
}

# 检查命令是否应该被排除
function script:_md_should_exclude {
    param([string]$cmd)
    
    if (-not $cmd) { return $true }
    if (-not $script:_MD_EXCLUDE_PATTERN) { return $false }
    
    return $cmd -match $script:_MD_EXCLUDE_PATTERN
}


# 初始化 Transcript 捕获
function script:_md_init_transcript {
    try {
        # 停止任何现有的 transcript
        Stop-Transcript -ErrorAction SilentlyContinue 2>$null
    } catch {}
    
    # 确保目录存在
    $transcriptDir = Split-Path $script:MD_TRANSCRIPT_FILE -Parent
    if (-not (Test-Path $transcriptDir)) {
        New-Item -ItemType Directory -Path $transcriptDir -Force | Out-Null
    }
    
    # 清空或创建 transcript 文件
    "" | Set-Content $script:MD_TRANSCRIPT_FILE -NoNewline
    
    try {
        Start-Transcript -Path $script:MD_TRANSCRIPT_FILE -Append -Force | Out-Null
        return $true
    } catch {
        return $false
    }
}

# 获取当前 transcript 文件大小
function script:_md_get_transcript_offset {
    if (Test-Path $script:MD_TRANSCRIPT_FILE) {
        return (Get-Item $script:MD_TRANSCRIPT_FILE).Length
    }
    return 0
}

# 从 transcript 截取指定范围的内容
function script:_md_read_transcript_range {
    param(
        [long]$startOffset,
        [long]$endOffset
    )
    
    if (-not (Test-Path $script:MD_TRANSCRIPT_FILE)) { return "" }
    if ($endOffset -le $startOffset) { return "" }
    
    try {
        $fs = [System.IO.FileStream]::new(
            $script:MD_TRANSCRIPT_FILE,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )
        try {
            $length = [Math]::Min($endOffset - $startOffset, $script:_MD_MAX_SIZE)
            $buffer = [byte[]]::new($length)
            $fs.Seek($startOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
            $bytesRead = $fs.Read($buffer, 0, $length)
            return [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)
        } finally {
            $fs.Close()
        }
    } catch {
        return ""
    }
}

# 清理 ANSI 转义序列和 transcript 头尾
function script:_md_clean_output {
    param([string]$text)
    
    if (-not $text) { return "" }
    
    # 移除 ANSI 转义序列
    $text = $text -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
    $text = $text -replace '\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)', ''
    $text = $text -replace '\x1b\([A-Z]', ''
    $text = $text -replace '\x1b[=>]', ''
    $text = $text -replace '\r', ''
    
    # 移除 transcript 特有的行（如时间戳、分隔线等）
    $lines = $text -split "`n"
    $cleanLines = $lines | Where-Object {
        $_ -notmatch '^\*{20,}' -and
        $_ -notmatch '^Windows PowerShell transcript' -and
        $_ -notmatch '^Start time:' -and
        $_ -notmatch '^End time:' -and
        $_ -notmatch '^Username:' -and
        $_ -notmatch '^RunAs User:' -and
        $_ -notmatch '^Configuration Name:' -and
        $_ -notmatch '^Machine:' -and
        $_ -notmatch '^Host Application:' -and
        $_ -notmatch '^Process ID:' -and
        $_ -notmatch '^PSVersion:' -and
        $_ -notmatch '^PSEdition:' -and
        $_ -notmatch '^PSCompatibleVersions:' -and
        $_ -notmatch '^BuildVersion:' -and
        $_ -notmatch '^CLRVersion:' -and
        $_ -notmatch '^WSManStackVersion:' -and
        $_ -notmatch '^PSRemotingProtocolVersion:' -and
        $_ -notmatch '^SerializationVersion:' -and
        $_ -notmatch '^Transcript started' -and
        $_ -notmatch '^Transcript ended'
    }
    
    return ($cleanLines -join "`n").Trim()
}


# 复制到剪贴板
function script:_md_copy {
    param([string]$text)
    
    $isRemote = $env:SSH_TTY -or $env:SSH_CLIENT
    
    # 本地环境优先用原生剪贴板
    if (-not $isRemote) {
        # Windows: 优先 Set-Clipboard，其次 clip.exe
        if ($IsWindows -or $env:OS -eq "Windows_NT" -or (-not $IsMacOS -and -not $IsLinux)) {
            try {
                Set-Clipboard -Value $text
                return $true
            } catch {
                try {
                    $text | clip.exe
                    return $true
                } catch {}
            }
        }
        
        # macOS: pbcopy
        if ($IsMacOS) {
            try {
                $text | pbcopy
                return $true
            } catch {}
        }
        
        # Linux: xclip 或 xsel
        if ($IsLinux) {
            if (Get-Command xclip -ErrorAction SilentlyContinue) {
                try {
                    $text | xclip -selection clipboard
                    return $true
                } catch {}
            }
            if (Get-Command xsel -ErrorAction SilentlyContinue) {
                try {
                    $text | xsel --clipboard
                    return $true
                } catch {}
            }
        }
    }
    
    # SSH 远程或无本地剪贴板：用 OSC 52
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($text))
    $osc = "`e]52;c;$encoded`a"
    
    # tmux 环境
    if ($env:TMUX) {
        if (Get-Command tmux -ErrorAction SilentlyContinue) {
            try {
                tmux set-buffer -w -- $text 2>$null
                return $true
            } catch {}
        }
        # tmux passthrough
        Write-Host "`ePtmux;$osc`e\" -NoNewline
    } else {
        Write-Host $osc -NoNewline
    }
    
    return $true
}

# 完成捕获：在 prompt 中调用
function script:_md_finalize_capture {
    $currentOffset = _md_get_transcript_offset
    
    if ($script:_MD_CURRENT_CMD) {
        # pre-hook 生效了，用记录的偏移
        $output = _md_read_transcript_range $script:_MD_START_OFFSET $currentOffset
        $output = _md_clean_output $output
        
        # 移除命令本身（通常在输出开头）
        $cmdPattern = [regex]::Escape($script:_MD_CURRENT_CMD)
        $output = $output -replace "^PS[^>]*>\s*$cmdPattern\s*`n?", ""
        $output = $output.Trim()
        
        if ($output) {
            $script:_MD_LAST_CMD = $script:_MD_CURRENT_CMD
            $output | Set-Content $script:MD_FILE -NoNewline
        }
        
        $script:_MD_CURRENT_CMD = ""
    } else {
        # 兜底：用 Get-History
        $lastHistory = Get-History -Count 1 -ErrorAction SilentlyContinue
        if ($lastHistory) {
            $cmd = $lastHistory.CommandLine
            if (-not (_md_should_exclude $cmd)) {
                $output = _md_read_transcript_range $script:_MD_LAST_END_OFFSET $currentOffset
                $output = _md_clean_output $output
                
                # 移除命令本身
                $cmdPattern = [regex]::Escape($cmd)
                $output = $output -replace "^PS[^>]*>\s*$cmdPattern\s*`n?", ""
                $output = $output.Trim()
                
                if ($output) {
                    $script:_MD_LAST_CMD = $cmd
                    $output | Set-Content $script:MD_FILE -NoNewline
                }
            }
        }
    }
    
    $script:_MD_LAST_END_OFFSET = $currentOffset
}


# PSReadLine CommandValidationHandler 作为 pre-hook
function script:_md_pre_hook {
    param([string]$commandAst)
    
    $cmd = $commandAst.ToString()
    
    if (_md_should_exclude $cmd) {
        $script:_MD_CURRENT_CMD = ""
        return
    }
    
    $script:_MD_CURRENT_CMD = $cmd
    $script:_MD_START_OFFSET = _md_get_transcript_offset
}

# 设置 PSReadLine hook
function script:_md_setup_psreadline_hook {
    if (Get-Module PSReadLine) {
        try {
            Set-PSReadLineOption -CommandValidationHandler {
                param([System.Management.Automation.Language.CommandAst]$commandAst)
                _md_pre_hook $commandAst
            }
        } catch {
            # PSReadLine 版本可能不支持 CommandValidationHandler
        }
    }
}

# 重写 prompt 函数作为 post-hook
function script:_md_setup_prompt_hook {
    # 保存原始 prompt
    $script:_MD_ORIGINAL_PROMPT = Get-Content Function:\prompt -ErrorAction SilentlyContinue
    
    # 定义新的 prompt
    function global:prompt {
        # 先完成捕获
        _md_finalize_capture
        
        # 调用原始 prompt
        if ($script:_MD_ORIGINAL_PROMPT) {
            & ([scriptblock]::Create($script:_MD_ORIGINAL_PROMPT))
        } else {
            "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
        }
    }
}

# 检查更新
function script:_md_check_update {
    $today = Get-Date -Format "yyyy-MM-dd"
    $lastCheck = ""
    
    if (Test-Path $script:MD_UPDATE_CHECK) {
        $lastCheck = Get-Content $script:MD_UPDATE_CHECK -ErrorAction SilentlyContinue
    }
    
    if ($lastCheck -eq $today) { return }
    
    $today | Set-Content $script:MD_UPDATE_CHECK -NoNewline
    
    try {
        $response = Invoke-WebRequest -Uri "$($script:MD_RAW_URL)/md.ps1" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.Content -match 'MD_VERSION\s*=\s*"([^"]+)"') {
            $remoteVersion = $Matches[1]
            if ($remoteVersion -ne $script:MD_VERSION) {
                Write-Host "md: new version available ($($script:MD_VERSION) -> $remoteVersion)"
                Write-Host "    run 'md update' to upgrade"
            }
        }
    } catch {}
}

# 更新
function script:_md_update {
    Write-Host "Updating md..."
    try {
        $mdPath = Join-Path $script:MD_DIR "md.ps1"
        Invoke-WebRequest -Uri "$($script:MD_RAW_URL)/md.ps1" -OutFile $mdPath -UseBasicParsing
        Write-Host "Updated. Restart PowerShell or run: . `$PROFILE"
    } catch {
        Write-Host "Update failed: $_" -ForegroundColor Red
    }
}

# 卸载
function script:_md_uninstall {
    Write-Host "Uninstalling md..."
    
    # 从 $PROFILE 移除加载行
    if (Test-Path $PROFILE) {
        $content = Get-Content $PROFILE -Raw
        $content = $content -replace '(?m)^.*\.md[/\\]md\.ps1.*$\r?\n?', ''
        $content = $content -replace '(?m)^.*md - copy last command.*$\r?\n?', ''
        $content | Set-Content $PROFILE
    }
    
    # 停止 transcript
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
    
    # 删除文件
    Remove-Item $script:MD_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\.md_output_*" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\.md_transcript_*" -Force -ErrorAction SilentlyContinue
    
    Write-Host "Done. Restart PowerShell."
}


# 排除列表管理
function script:_md_exclude_add {
    param([string]$cmd)
    
    if (-not $cmd) {
        Write-Host "usage: md exclude add <command>" -ForegroundColor Red
        return
    }
    
    if (-not (Test-Path $script:MD_DIR)) {
        New-Item -ItemType Directory -Path $script:MD_DIR -Force | Out-Null
    }
    
    $existing = @()
    if (Test-Path $script:MD_EXCLUDE_FILE) {
        $existing = Get-Content $script:MD_EXCLUDE_FILE -ErrorAction SilentlyContinue
    }
    
    if ($existing -contains $cmd) {
        Write-Host "'$cmd' already excluded"
    } else {
        $cmd | Add-Content $script:MD_EXCLUDE_FILE
        _md_build_exclude
        Write-Host "added '$cmd' to exclude list"
    }
}

function script:_md_exclude_rm {
    param([string]$cmd)
    
    if (-not $cmd) {
        Write-Host "usage: md exclude rm <command>" -ForegroundColor Red
        return
    }
    
    if (-not (Test-Path $script:MD_EXCLUDE_FILE)) {
        Write-Host "'$cmd' not in user exclude list"
        return
    }
    
    $content = Get-Content $script:MD_EXCLUDE_FILE -ErrorAction SilentlyContinue
    if ($content -contains $cmd) {
        $content | Where-Object { $_ -ne $cmd } | Set-Content $script:MD_EXCLUDE_FILE
        _md_build_exclude
        Write-Host "removed '$cmd' from exclude list"
    } else {
        Write-Host "'$cmd' not in user exclude list"
    }
}

function script:_md_exclude_list {
    Write-Host "Default excluded commands:"
    $script:_MD_DEFAULT_EXCLUDE | ForEach-Object { Write-Host "  $_" }
    Write-Host ""
    
    if ((Test-Path $script:MD_EXCLUDE_FILE) -and (Get-Item $script:MD_EXCLUDE_FILE).Length -gt 0) {
        Write-Host "User excluded commands (~/.md/exclude):"
        Get-Content $script:MD_EXCLUDE_FILE | 
            Where-Object { $_ -and $_ -notmatch '^\s*#' } |
            ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "User excluded commands: (none)"
    }
}

# 帮助信息
function script:_md_help {
    Write-Host "md - copy last command and output to clipboard"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  md                    copy last command to clipboard"
    Write-Host "  md exclude list       show excluded commands"
    Write-Host "  md exclude add <cmd>  add command to exclude list"
    Write-Host "  md exclude rm <cmd>   remove command from exclude list"
    Write-Host "  md update             update to latest version"
    Write-Host "  md uninstall          remove md"
    Write-Host "  md version            show version"
}

# 主函数
function global:_md_main {
    param(
        [Parameter(Position = 0)]
        [string]$Command,
        
        [Parameter(Position = 1)]
        [string]$SubCommand,
        
        [Parameter(Position = 2)]
        [string]$Argument
    )
    
    switch ($Command) {
        "update" {
            _md_update
            return
        }
        "uninstall" {
            _md_uninstall
            return
        }
        { $_ -in "version", "-v", "--version" } {
            Write-Host "md $($script:MD_VERSION)"
            return
        }
        "exclude" {
            switch ($SubCommand) {
                "add" { _md_exclude_add $Argument }
                { $_ -in "rm", "remove" } { _md_exclude_rm $Argument }
                { $_ -in "list", "ls", "" } { _md_exclude_list }
                default {
                    Write-Host "usage: md exclude [add|rm|list] [command]" -ForegroundColor Red
                }
            }
            return
        }
        { $_ -in "help", "-h", "--help" } {
            _md_help
            return
        }
        "" {
            # 默认行为：复制上一条命令和输出
            if (-not $script:_MD_LAST_CMD -or -not (Test-Path $script:MD_FILE)) {
                Write-Host "no record" -ForegroundColor Red
                return
            }
            
            $output = Get-Content $script:MD_FILE -Raw -ErrorAction SilentlyContinue
            if (-not $output) {
                Write-Host "no record" -ForegroundColor Red
                return
            }
            
            $content = "$ $($script:_MD_LAST_CMD)`n$output"
            
            if (_md_copy $content) {
                Write-Host "copied"
            } else {
                Write-Host "copy failed" -ForegroundColor Red
            }
            return
        }
        default {
            Write-Host "unknown command: $Command" -ForegroundColor Red
            Write-Host "run 'md help' for usage"
        }
    }
}


# 初始化
if (-not $script:_MD_INIT) {
    $script:_MD_INIT = $true
    
    # 确保 .md 目录存在
    if (-not (Test-Path $script:MD_DIR)) {
        New-Item -ItemType Directory -Path $script:MD_DIR -Force | Out-Null
    }
    
    # 构建排除列表
    _md_build_exclude
    
    # 初始化 transcript 捕获
    if (_md_init_transcript) {
        # 设置 PSReadLine pre-hook
        _md_setup_psreadline_hook
        
        # 设置 prompt post-hook
        _md_setup_prompt_hook
        
        # 记录初始偏移
        $script:_MD_LAST_END_OFFSET = _md_get_transcript_offset
    } else {
        Write-Warning "md: Failed to start transcript. Output capture may not work."
    }
    
    # 后台检查更新
    Start-Job -ScriptBlock {
        param($checkFunc, $updateCheckPath, $rawUrl, $version)
        
        $today = Get-Date -Format "yyyy-MM-dd"
        $lastCheck = ""
        if (Test-Path $updateCheckPath) {
            $lastCheck = Get-Content $updateCheckPath -ErrorAction SilentlyContinue
        }
        if ($lastCheck -eq $today) { return }
        
        $today | Set-Content $updateCheckPath -NoNewline
        
        try {
            $response = Invoke-WebRequest -Uri "$rawUrl/md.ps1" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.Content -match 'MD_VERSION\s*=\s*"([^"]+)"') {
                $remoteVersion = $Matches[1]
                if ($remoteVersion -ne $version) {
                    # 写入提示文件，下次 prompt 时显示
                    "$remoteVersion" | Set-Content (Join-Path (Split-Path $updateCheckPath) ".new_version") -NoNewline
                }
            }
        } catch {}
    } -ArgumentList @($null, $script:MD_UPDATE_CHECK, $script:MD_RAW_URL, $script:MD_VERSION) | Out-Null
}

# 注册退出事件清理临时文件
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
    Remove-Item "$env:TEMP\.md_transcript_$PID.log" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\.md_output_$PID.log" -Force -ErrorAction SilentlyContinue
} -SupportEvent | Out-Null

# Command name: configurable via MD_CMD_NAME env var (default: md)
# Users who prefer 'mdd' can set $env:MD_CMD_NAME = "mdd" before sourcing
$script:MD_CMD_NAME = if ($env:MD_CMD_NAME) { $env:MD_CMD_NAME } else { "md" }

# Remove built-in md alias (mkdir shortcut) only if using 'md' as command name
if ($script:MD_CMD_NAME -eq "md") {
    Remove-Item Alias:md -Force -ErrorAction SilentlyContinue
}

# Create the command alias
Set-Alias -Name $script:MD_CMD_NAME -Value _md_main -Scope Global
