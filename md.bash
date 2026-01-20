#!/bin/bash
# md - copy last command and output to clipboard

MD_VERSION="1.2.0"
MD_REPO="Cishoon/md"
MD_RAW_URL="https://raw.githubusercontent.com/$MD_REPO/main"
MD_FILE="${TMPDIR:-/tmp}/.md_output_$$"
MD_UPDATE_CHECK="$HOME/.md/.last_update_check"

[[ $- != *i* ]] && return

if [[ -z "$_MD_INIT" ]]; then
    _MD_INIT=1
    _MD_LAST_CMD=""
    _MD_CURRENT_CMD=""
    _MD_EXCLUDE='^[[:space:]]*(md|clear|reset|exit|cd|pwd|history|fg|bg|vim|vi|nano|less|more|top|htop|man|ssh|sudo|nload|iftop|watch|tail|journalctl|tmux|screen|emacs|nvim|mc|ranger|lazygit|tig|fzf|bat|delta)([[:space:]]|$)'
    
    _md_debug() {
        [[ $BASH_COMMAND == _md_* ]] && return 0
        [[ $BASH_COMMAND == "$PROMPT_COMMAND" ]] && return 0
        
        local cmd
        cmd="$(history 1 | sed 's/^[ ]*[0-9]*[ ]*//')"
        
        [[ "$cmd" =~ $_MD_EXCLUDE ]] && return 0
        [[ -n "$_MD_CURRENT_CMD" ]] && return 0
        
        _MD_CURRENT_CMD="$cmd"
        exec 3>&1 4>&2
        exec > >(tee "$MD_FILE") 2>&1
        
        return 0
    }
    
    _md_precmd() {
        [[ -z "$_MD_CURRENT_CMD" ]] && return
        
        exec 1>&3 2>&4 3>&- 4>&-
        
        _MD_LAST_CMD="$_MD_CURRENT_CMD"
        _MD_CURRENT_CMD=""
    }
    
    trap '_md_debug' DEBUG
    PROMPT_COMMAND="_md_precmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi

_md_copy() {
    local input
    input=$(cat)
    local encoded
    encoded=$(echo -n "$input" | base64 | tr -d '\n')
    printf '\033]52;c;%s\a' "$encoded"
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
