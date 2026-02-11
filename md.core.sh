# Shared core for md shell integrations.

MD_VERSION="1.4.0"
MD_REPO="Cishoon/md"
MD_RAW_URL="https://raw.githubusercontent.com/$MD_REPO/main"
MD_FILE="${TMPDIR:-/tmp}/.md_output_$$"
MD_UPDATE_CHECK="$HOME/.md/.last_update_check"
MD_EXCLUDE_FILE="$HOME/.md/exclude"
MD_ENABLED_FILE="$HOME/.md/enabled"
_MD_MAX_SIZE=$((32 * 1024 * 1024))

# Command name: configurable via MD_CMD_NAME (default: md)
: "${MD_CMD_NAME:=md}"

# Adapter-provided metadata (used by update/uninstall)
# To add a new shell adapter (e.g. fish), provide these three values
# before sourcing this file, then implement shell-specific capture hooks.
: "${MD_SHELL_NAME:=bash}"
: "${MD_UPDATE_TARGET:=md.bash}"
: "${MD_RC_FILE:=$HOME/.bashrc}"

# Default excluded commands (interactive commands only)
_MD_DEFAULT_EXCLUDE="$MD_CMD_NAME|clear|reset|exit|fg|bg|vim|vi|nano|less|more|top|htop|man|ssh|nload|iftop|watch|journalctl|tmux|screen|emacs|nvim|mc|ranger|lazygit|tig|fzf|ls|ll"

_md_init_shared() {
    if [[ -n "$_MD_SHARED_INIT" ]]; then
        return
    fi

    _MD_SHARED_INIT=1
    _MD_LAST_CMD=""
    _md_build_exclude
}

# Build exclude regex with user additions
_md_build_exclude() {
    local user_exclude=""
    if [[ -f "$MD_EXCLUDE_FILE" ]]; then
        user_exclude=$(grep -v '^#' "$MD_EXCLUDE_FILE" 2>/dev/null | grep -v '^$' | tr '\n' '|' | sed 's/|$//')
    fi

    if [[ -n "$user_exclude" ]]; then
        _MD_EXCLUDE="^[[:space:]]*(${_MD_DEFAULT_EXCLUDE}|${user_exclude})([[:space:]]|$)"
    else
        _MD_EXCLUDE="^[[:space:]]*(${_MD_DEFAULT_EXCLUDE})([[:space:]]|$)"
    fi
}

_md_copy() {
    local input
    input=$(cat)

    # Local environment prefers native clipboard tools first.
    if [[ -z "$SSH_TTY" && -z "$SSH_CLIENT" ]]; then
        if command -v pbcopy >/dev/null 2>&1; then
            printf '%s' "$input" | pbcopy && return 0
        elif command -v xclip >/dev/null 2>&1; then
            printf '%s' "$input" | xclip -selection clipboard && return 0
        elif command -v xsel >/dev/null 2>&1; then
            printf '%s' "$input" | xsel --clipboard && return 0
        elif command -v termux-clipboard-set >/dev/null 2>&1; then
            printf '%s' "$input" | termux-clipboard-set && return 0
        fi
    fi

    # SSH remote or no local clipboard: fallback to OSC 52.
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
    local today
    today=$(date +%Y-%m-%d)

    local last_check=""
    [[ -f "$MD_UPDATE_CHECK" ]] && last_check=$(cat "$MD_UPDATE_CHECK" 2>/dev/null)
    [[ "$last_check" == "$today" ]] && return

    mkdir -p "$(dirname "$MD_UPDATE_CHECK")"
    echo "$today" > "$MD_UPDATE_CHECK"

    local remote_version
    remote_version=$(curl -fsSL --connect-timeout 2 "$MD_RAW_URL/$MD_UPDATE_TARGET" 2>/dev/null | grep '^MD_VERSION=' | head -1 | cut -d'"' -f2)

    if [[ -n "$remote_version" ]] && [[ "$remote_version" != "$MD_VERSION" ]]; then
        echo "$MD_CMD_NAME: new version available ($MD_VERSION -> $remote_version)"
        echo "    run '$MD_CMD_NAME update' to upgrade"
    fi
}

_md_update() {
    echo "Updating $MD_CMD_NAME..."
    curl -fsSL "$MD_RAW_URL/install-online.sh" | MD_CMD_NAME="$MD_CMD_NAME" bash
}

_md_sed_delete() {
    local pattern="$1"
    local target="$2"

    [[ ! -f "$target" ]] && return

    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$pattern" "$target" 2>/dev/null
    else
        sed -i "$pattern" "$target" 2>/dev/null
    fi
}

_md_uninstall() {
    echo "Uninstalling $MD_CMD_NAME..."

    _md_sed_delete '/\.md\/md\.sh/d' "$MD_RC_FILE"
    _md_sed_delete '/md - copy last command/d' "$MD_RC_FILE"
    _md_sed_delete '/^MD_CMD_NAME=/d' "$MD_RC_FILE"

    rm -rf "$HOME/.md"
    rm -f "${TMPDIR:-/tmp}/.md_output_"*

    echo "Done. Restart shell."
}

_md_exclude_add() {
    local cmd="$1"
    [[ -z "$cmd" ]] && { echo "usage: $MD_CMD_NAME exclude add <command>" >&2; return 1; }

    mkdir -p "$(dirname "$MD_EXCLUDE_FILE")"

    if grep -qxF "$cmd" "$MD_EXCLUDE_FILE" 2>/dev/null; then
        echo "'$cmd' already excluded"
    else
        echo "$cmd" >> "$MD_EXCLUDE_FILE"
        _md_build_exclude
        echo "added '$cmd' to exclude list"
    fi
}

_md_exclude_rm() {
    local cmd="$1"
    [[ -z "$cmd" ]] && { echo "usage: $MD_CMD_NAME exclude rm <command>" >&2; return 1; }

    if [[ ! -f "$MD_EXCLUDE_FILE" ]]; then
        echo "'$cmd' not in user exclude list"
        return 1
    fi

    if grep -qxF "$cmd" "$MD_EXCLUDE_FILE" 2>/dev/null; then
        local tmp
        tmp=$(mktemp "${MD_EXCLUDE_FILE}.XXXXXX") || return 1
        grep -vxF "$cmd" "$MD_EXCLUDE_FILE" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$MD_EXCLUDE_FILE"
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

_md_is_enabled() {
    [[ ! -f "$MD_ENABLED_FILE" ]] && return 0

    local val
    val=$(cat "$MD_ENABLED_FILE" 2>/dev/null)
    [[ "$val" == "0" ]] && return 1
    return 0
}

_md_on() {
    mkdir -p "$(dirname "$MD_ENABLED_FILE")"
    echo "1" > "$MD_ENABLED_FILE"
    echo "$MD_CMD_NAME: enabled"
}

_md_off() {
    mkdir -p "$(dirname "$MD_ENABLED_FILE")"
    echo "0" > "$MD_ENABLED_FILE"
    echo "$MD_CMD_NAME: disabled"
}

_md_status() {
    if _md_is_enabled; then
        echo "$MD_CMD_NAME: on"
    else
        echo "$MD_CMD_NAME: off"
    fi
}

_md_help() {
    echo "$MD_CMD_NAME - copy last command and output to clipboard"
    echo ""
    echo "Usage:"
    echo "  $MD_CMD_NAME                    copy last command to clipboard"
    echo "  $MD_CMD_NAME on                 enable $MD_CMD_NAME"
    echo "  $MD_CMD_NAME off                disable $MD_CMD_NAME (ignore all commands)"
    echo "  $MD_CMD_NAME status             show current on/off state"
    echo "  $MD_CMD_NAME exclude list       show excluded commands"
    echo "  $MD_CMD_NAME exclude add <cmd>  add command to exclude list"
    echo "  $MD_CMD_NAME exclude rm <cmd>   remove command from exclude list"
    echo "  $MD_CMD_NAME update             update to latest version"
    echo "  $MD_CMD_NAME uninstall          remove $MD_CMD_NAME"
    echo "  $MD_CMD_NAME version            show version"
}

_md_main() {
    case "$1" in
        on)
            _md_on
            return
            ;;
        off)
            _md_off
            return
            ;;
        status)
            _md_status
            return
            ;;
        update)
            _md_update
            return
            ;;
        uninstall)
            _md_uninstall
            return
            ;;
        version|-v|--version)
            echo "$MD_CMD_NAME $MD_VERSION"
            return
            ;;
        exclude)
            case "$2" in
                add) _md_exclude_add "$3" ;;
                rm|remove) _md_exclude_rm "$3" ;;
                list|ls|"") _md_exclude_list ;;
                *) echo "usage: $MD_CMD_NAME exclude [add|rm|list] [command]" >&2; return 1 ;;
            esac
            return
            ;;
        help|-h|--help)
            _md_help
            return
            ;;
    esac

    if ! _md_is_enabled; then
        echo "$MD_CMD_NAME: disabled (run '$MD_CMD_NAME on' to enable)" >&2
        return 1
    fi

    if [[ -z "$_MD_LAST_CMD" ]] || [[ ! -s "$MD_FILE" ]]; then
        echo "no record" >&2
        return 1
    fi

    {
        echo "$ $_MD_LAST_CMD"
        cat "$MD_FILE" 2>/dev/null | _md_clean
    } | _md_copy && echo "copied"
}

_md_register_command() {
    if [[ "$MD_CMD_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        unalias "$MD_CMD_NAME" >/dev/null 2>&1 || true
        eval "function ${MD_CMD_NAME}() { _md_main \"\$@\"; }"
    else
        alias "$MD_CMD_NAME"='_md_main'
    fi
}
