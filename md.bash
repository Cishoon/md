#!/bin/bash
# md - copy last command and output to clipboard

MD_VERSION="1.1.0"
MD_REPO="Cishoon/md"
MD_RAW_URL="https://raw.githubusercontent.com/$MD_REPO/main"
MD_UPDATE_CHECK="$HOME/.md/.last_update_check"

[[ $- != *i* ]] && return

MD_DIR="${TMPDIR:-/tmp}/md-$(id -u)"
MD_LOG="$MD_DIR/session_$$.log"

mkdir -p "$MD_DIR" 2>/dev/null

_MD_EXCLUDE='^[[:space:]]*(md|clear|reset|exit|cd|pwd|history|fg|bg|vim|vi|nano|less|more|top|htop|man|ssh|sudo)([[:space:]]|$)'

if [[ -z "$_MD_INIT" ]]; then
    export _MD_INIT=1
    
    exec 3>&1 4>&2
    exec > >(tee -a "$MD_LOG" >&3) 2> >(tee -a "$MD_LOG" >&4)
    
    _md_ready=1
    _md_current_cmd=""
    _md_last_cmd=""
    _md_last_start=0
    _md_last_end=0
    _md_start=0
    _md_end=0
    
    _md_filesize() {
        stat -f%z "$MD_LOG" 2>/dev/null || stat -c%s "$MD_LOG" 2>/dev/null || wc -c < "$MD_LOG"
    }
    
    _md_debug() {
        [[ $_md_ready != 1 ]] && return 0
        [[ $BASH_COMMAND == _md_* ]] && return 0
        [[ $BASH_COMMAND =~ $_MD_EXCLUDE ]] && return 0
        
        _md_current_cmd="$BASH_COMMAND"
        _md_start="$(_md_filesize)"
        _md_ready=0
        return 0
    }
    
    _md_prompt() {
        local rc=$?
        if [[ -n "$_md_current_cmd" ]]; then
            _md_end="$(_md_filesize)"
            _md_last_cmd="$_md_current_cmd"
            _md_last_start="$_md_start"
            _md_last_end="$_md_end"
            _md_current_cmd=""
        fi
        _md_ready=1
    }
    
    trap '_md_debug' DEBUG
    PROMPT_COMMAND="_md_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
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
    rm -rf "${TMPDIR:-/tmp}/md-"*
    
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
    
    [[ -z "$_md_last_cmd" ]] && { echo "no record" >&2; return 1; }
    
    local len=$(( _md_last_end - _md_last_start ))
    local output=""
    (( len > 0 )) && output=$(dd if="$MD_LOG" bs=1 skip="$_md_last_start" count="$len" 2>/dev/null)
    
    {
        echo "$ $_md_last_cmd"
        echo "$output" | _md_clean
    } | _md_copy && echo "copied"
}

# Check for updates daily (background, non-blocking)
(_md_check_update &) 2>/dev/null
