#!/bin/bash
# md - copy last command and output to clipboard

MD_VERSION="1.4.0"
MD_REPO="Cishoon/md"
MD_RAW_URL="https://raw.githubusercontent.com/$MD_REPO/main"
MD_FILE="${TMPDIR:-/tmp}/.md_output_$$"
MD_UPDATE_CHECK="$HOME/.md/.last_update_check"
MD_EXCLUDE_FILE="$HOME/.md/exclude"
_MD_MAX_SIZE=$((32 * 1024 * 1024))

# 默认排除列表（仅交互式命令）
_MD_DEFAULT_EXCLUDE='md|clear|reset|exit|fg|bg|vim|vi|nano|less|more|top|htop|man|ssh|nload|iftop|watch|journalctl|tmux|screen|emacs|nvim|mc|ranger|lazygit|tig|fzf|ls|ll'

[[ $- != *i* ]] && return

# JetBrains 终端不支持，直接禁用
if [[ "$TERMINAL_EMULATOR" == *"JetBrains"* ]]; then
    md() { echo "md: not supported in JetBrains terminal" >&2; return 1; }
    return 0
fi

# 构建排除正则
_md_build_exclude() {
    local user_exclude=""
    if [[ -f "$MD_EXCLUDE_FILE" ]]; then
        user_exclude=$(grep -v '^#' "$MD_EXCLUDE_FILE" 2>/dev/null | grep -v '^$' | tr '\n' '|' | sed 's/|$//')
    fi
    
    if [[ -n "$user_exclude" ]]; then
        _MD_EXCLUDE="^[[:space:]]*(${_MD_DEFAULT_EXCLUDE}|${user_exclude})([[:space:]]|\$)"
    else
        _MD_EXCLUDE="^[[:space:]]*(${_MD_DEFAULT_EXCLUDE})([[:space:]]|\$)"
    fi
}

if [[ -z "$_MD_INIT" ]]; then
    _MD_INIT=1
    _MD_LAST_CMD=""
    _MD_CURRENT_CMD=""
    _MD_CAPTURE_ACTIVE=0
    _MD_READY=0
    _md_build_exclude
    
    _md_mark_prompt() {
        _MD_READY=1
    }
    
    _md_debug() {
        [[ $_MD_READY -eq 1 ]] || return 0
        _MD_READY=0
        
        local cmd="$BASH_COMMAND"
        [[ $cmd == _md_* ]] && return 0
        [[ "$cmd" =~ $_MD_EXCLUDE ]] && return 0
        
        _MD_CAPTURE_ACTIVE=1
        _MD_CURRENT_CMD="$cmd"
        exec 3>&1 4>&2
        exec > >(tee "$MD_FILE") 2>&1
        
        return 0
    }
    
    _md_precmd() {
        [[ $_MD_CAPTURE_ACTIVE -eq 0 ]] && return
        
        exec 1>&3 2>&4 3>&- 4>&-
        
        local last_cmd
        last_cmd=$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//') 2>/dev/null || last_cmd=""
        [[ -z "$last_cmd" ]] && last_cmd="$_MD_CURRENT_CMD"
        
        _MD_LAST_CMD="$last_cmd"
        _MD_CAPTURE_ACTIVE=0
        _MD_CURRENT_CMD=""

        _md_trim_file
    }
    
    trap '_md_debug' DEBUG
    PROMPT_COMMAND="_md_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}; _md_mark_prompt"
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

    if [[ -n "$TMUX" ]] && command -v tmux >/dev/null 2>&1; then
        tmux set-buffer -w -- "$input" >/dev/null 2>&1 && return 0
    fi

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
    remote_version=$(curl -fsSL --connect-timeout 2 "$MD_RAW_URL/md.bash" 2>/dev/null | grep '^MD_VERSION=' | head -1 | cut -d'"' -f2)
    
    if [[ -n "$remote_version" ]] && [[ "$remote_version" != "$MD_VERSION" ]]; then
        echo "md: new version available ($MD_VERSION -> $remote_version)"
        echo "    run 'md update' to upgrade"
    fi
}

_md_update() {
    echo "Updating md..."
    curl -fsSL "$MD_RAW_URL/md.bash" -o "$HOME/.md/md.sh" && \
    echo "Updated. Restart shell or run: source ~/.bashrc"
}

_md_uninstall() {
    echo "Uninstalling md..."
    
    local rc_file="$HOME/.bashrc"
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' '/\.md\/md\.sh/d' "$rc_file" 2>/dev/null
        sed -i '' '/md - copy last command/d' "$rc_file" 2>/dev/null
    else
        sed -i '/\.md\/md\.sh/d' "$rc_file" 2>/dev/null
        sed -i '/md - copy last command/d' "$rc_file" 2>/dev/null
    fi
    
    rm -rf "$HOME/.md"
    rm -f "${TMPDIR:-/tmp}/.md_output_"*
    
    echo "Done. Restart shell."
}

_md_exclude_add() {
    local cmd="$1"
    [[ -z "$cmd" ]] && { echo "usage: md exclude add <command>" >&2; return 1; }
    
    mkdir -p "$(dirname "$MD_EXCLUDE_FILE")"
    
    if grep -qx "$cmd" "$MD_EXCLUDE_FILE" 2>/dev/null; then
        echo "'$cmd' already excluded"
    else
        echo "$cmd" >> "$MD_EXCLUDE_FILE"
        _md_build_exclude
        echo "added '$cmd' to exclude list"
    fi
}

_md_exclude_rm() {
    local cmd="$1"
    [[ -z "$cmd" ]] && { echo "usage: md exclude rm <command>" >&2; return 1; }
    
    if [[ ! -f "$MD_EXCLUDE_FILE" ]]; then
        echo "'$cmd' not in user exclude list"
        return 1
    fi
    
    if grep -qx "$cmd" "$MD_EXCLUDE_FILE" 2>/dev/null; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "/^${cmd}$/d" "$MD_EXCLUDE_FILE"
        else
            sed -i "/^${cmd}$/d" "$MD_EXCLUDE_FILE"
        fi
        _md_build_exclude
        echo "removed '$cmd' from exclude list"
    else
        echo "'$cmd' not in user exclude list"
        return 1
    fi
}

_md_exclude_list() {
    echo "Default excluded commands:"
    echo "$_MD_DEFAULT_EXCLUDE" | tr '|' '\n' | sed 's/^/  /'
    echo ""
    if [[ -f "$MD_EXCLUDE_FILE" ]] && [[ -s "$MD_EXCLUDE_FILE" ]]; then
        echo "User excluded commands (~/.md/exclude):"
        grep -v '^#' "$MD_EXCLUDE_FILE" | grep -v '^$' | sed 's/^/  /'
    else
        echo "User excluded commands: (none)"
    fi
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
        exclude)
            case "$2" in
                add) _md_exclude_add "$3" ;;
                rm|remove) _md_exclude_rm "$3" ;;
                list|ls|"") _md_exclude_list ;;
                *) echo "usage: md exclude [add|rm|list] [command]" >&2; return 1 ;;
            esac
            return
            ;;
        help|-h|--help)
            echo "md - copy last command and output to clipboard"
            echo ""
            echo "Usage:"
            echo "  md                    copy last command to clipboard"
            echo "  md exclude list       show excluded commands"
            echo "  md exclude add <cmd>  add command to exclude list"
            echo "  md exclude rm <cmd>   remove command from exclude list"
            echo "  md update             update to latest version"
            echo "  md uninstall          remove md"
            echo "  md version            show version"
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
