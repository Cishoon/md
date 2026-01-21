#!/bin/zsh
# md - copy last command and output to clipboard

MD_VERSION="1.2.0"
MD_REPO="Cishoon/md"
MD_RAW_URL="https://raw.githubusercontent.com/$MD_REPO/main"
MD_FILE="${TMPDIR:-/tmp}/.md_output_$$"
MD_UPDATE_CHECK="$HOME/.md/.last_update_check"
_MD_MAX_SIZE=$((32 * 1024 * 1024))

# JetBrains 终端不支持，直接禁用
if [[ "$TERMINAL_EMULATOR" == *"JetBrains"* ]]; then
    md() { echo "md: not supported in JetBrains terminal" >&2; return 1; }
    return 0
fi

if [[ -z "$_MD_INIT" ]]; then
    _MD_INIT=1
    _MD_LAST_CMD=""
    _MD_EXCLUDE='^[[:space:]]*(md|clear|reset|exit|cd|pwd|history|fg|bg|vim|vi|nano|less|more|top|htop|man|ssh|sudo|nload|iftop|watch|tail|journalctl|tmux|screen|emacs|nvim|mc|ranger|lazygit|tig|fzf|bat|delta)([[:space:]]|$)'
    
    autoload -Uz add-zsh-hook
    
    _md_preexec() {
        local cmd="$1"
        [[ "$cmd" =~ $_MD_EXCLUDE ]] && return
        
        _MD_CURRENT_CMD="$cmd"
        exec 3>&1 4>&2
        exec > >(tee "$MD_FILE") 2>&1
    }
    
    _md_precmd() {
        [[ -z "$_MD_CURRENT_CMD" ]] && return
        
        exec 1>&3 2>&4 3>&- 4>&-
        
        _MD_LAST_CMD="$_MD_CURRENT_CMD"
        _MD_CURRENT_CMD=""

        _md_trim_file
    }
    
    add-zsh-hook preexec _md_preexec
    add-zsh-hook precmd _md_precmd
fi

_md_copy() {
    local input
    input=$(cat)

    # 本地环境优先用原生剪贴板命令
    if [[ -z "$SSH_TTY" && -z "$SSH_CLIENT" ]]; then
        if command -v pbcopy &>/dev/null; then
            printf '%s' "$input" | pbcopy && return 0
        elif command -v xclip &>/dev/null; then
            printf '%s' "$input" | xclip -selection clipboard && return 0
        elif command -v xsel &>/dev/null; then
            printf '%s' "$input" | xsel --clipboard && return 0
        fi
    fi

    # SSH 远程或无本地剪贴板时用 OSC 52
    local encoded
    encoded=$(printf '%s' "$input" | base64 | tr -d '\n')
    local osc
    osc=$(printf '\033]52;c;%s\a' "$encoded")

    # Prefer tmux clipboard helper if available; it handles OSC 52 safely
    if [[ -n "$TMUX" ]] && command -v tmux >/dev/null 2>&1; then
        tmux set-buffer -w -- "$input" >/dev/null 2>&1 && return 0
    fi

    # Wrap OSC 52 for tmux so it passes through to the host terminal
    if [[ -n "$TMUX" ]]; then
        printf '\033Ptmux;%s\033\\' "$osc"
    else
        printf '%s' "$osc"
    fi
}

_md_trim_file() {
    [[ ! -f "$MD_FILE" ]] && return
    local size
    size=$(wc -c < "$MD_FILE" 2>/dev/null || echo 0)
    (( size <= _MD_MAX_SIZE )) && return
    local tmp="${MD_FILE}.tmp"
    tail -c "$_MD_MAX_SIZE" "$MD_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$MD_FILE"
}

_md_clean() {
    perl -pe '
        s/\e\][^\a\e]*(?:\a|\e\\)//g;
        s/\e\[[0-9;]*[a-zA-Z]//g;
        s/\e\([A-Z]//g;
        s/\e[=>]//g;
        s/\r//g;
    ' 2>/dev/null || cat
}

_md_check_update() {
    local today=$(date +%Y-%m-%d)
    local last_check=""
    [[ -f "$MD_UPDATE_CHECK" ]] && last_check=$(cat "$MD_UPDATE_CHECK" 2>/dev/null)
    
    [[ "$last_check" == "$today" ]] && return
    
    echo "$today" > "$MD_UPDATE_CHECK"
    
    local remote_version
    remote_version=$(curl -fsSL --connect-timeout 2 "$MD_RAW_URL/md.zsh" 2>/dev/null | grep '^MD_VERSION=' | head -1 | cut -d'"' -f2)
    
    if [[ -n "$remote_version" ]] && [[ "$remote_version" != "$MD_VERSION" ]]; then
        echo "md: new version available ($MD_VERSION -> $remote_version)"
        echo "    run 'md update' to upgrade"
    fi
}

_md_update() {
    echo "Updating md..."
    curl -fsSL "$MD_RAW_URL/md.zsh" -o "$HOME/.md/md.sh" && \
    echo "Updated. Restart shell or run: source ~/.zshrc"
}

_md_uninstall() {
    echo "Uninstalling md..."
    
    local rc_file="$HOME/.zshrc"
    [[ -f "$rc_file" ]] && sed -i '' '/\.md\/md\.sh/d' "$rc_file" 2>/dev/null
    [[ -f "$rc_file" ]] && sed -i '' '/md - copy last command/d' "$rc_file" 2>/dev/null
    
    rm -rf "$HOME/.md"
    rm -f "${TMPDIR:-/tmp}/.md_output_"*
    
    echo "Done. Restart shell."
}

md() {
    case "$1" in
        update)
            _md_update
            return
            ;;
        uninstall)
            _md_uninstall
            return
            ;;
        version|-v|--version)
            echo "md $MD_VERSION"
            return
            ;;
        help|-h|--help)
            echo "md - copy last command and output to clipboard"
            echo ""
            echo "Usage:"
            echo "  md            copy last command to clipboard"
            echo "  md update     update to latest version"
            echo "  md uninstall  remove md"
            echo "  md version    show version"
            return
            ;;
    esac
    
    if [[ -z "$_MD_LAST_CMD" ]] || [[ ! -s "$MD_FILE" ]]; then
        echo "no record" >&2
        return 1
    fi
    
    {
        echo "$ $_MD_LAST_CMD"
        cat "$MD_FILE" 2>/dev/null | _md_clean
    } | _md_copy && echo "copied"
}

# Check for updates daily (background, non-blocking)
(_md_check_update &) 2>/dev/null
