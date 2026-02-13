#!/usr/bin/fish
# md - copy last command and output to clipboard (fish adapter)
# Fish cannot source POSIX shell, so core logic is reimplemented natively.
#
# Capture strategy: on session start, re-exec fish under `script(1)` to
# record all terminal output to a log file.  fish_preexec/fish_postexec
# record byte offsets so we can slice per-command output from the log.
# `script` is available on macOS and virtually all Linux distros.

status --is-interactive; or exit

# Prevent double init
set -q _MD_INIT; and exit

# ── version & constants ──────────────────────────────────────────────
set -g MD_VERSION "1.4.0"
set -g MD_REPO "Cishoon/md"
set -g MD_RAW_URL "https://raw.githubusercontent.com/$MD_REPO/main"

set -q MD_CMD_NAME; or set -g MD_CMD_NAME md

set -g MD_SHELL_NAME fish
set -g MD_UPDATE_TARGET md.fish
set -g MD_RC_FILE "$HOME/.config/fish/config.fish"

set -g _MD_DIR (set -q XDG_CACHE_HOME; and echo $XDG_CACHE_HOME; or echo "$HOME/.cache")/md
mkdir -p $_MD_DIR

set -g MD_UPDATE_CHECK "$HOME/.md/.last_update_check"
set -g MD_EXCLUDE_FILE "$HOME/.md/exclude"
set -g MD_ENABLED_FILE "$HOME/.md/enabled"
set -g _MD_MAX_SIZE (math "32 * 1024 * 1024")

set -g _MD_DEFAULT_EXCLUDE "$MD_CMD_NAME|clear|reset|exit|fg|bg|vim|vi|nano|less|more|top|htop|man|ssh|nload|iftop|watch|journalctl|tmux|screen|emacs|nvim|mc|ranger|lazygit|tig|fzf|ls|ll"


# ── bootstrap: re-exec under script(1) ──────────────────────────────
# script(1) records all terminal I/O to a file transparently.
# We re-exec fish under script so all output is captured.
# _MD_UNDER_SCRIPT prevents infinite recursion.
# The log path is exported as _MD_LOG so the new fish process uses the
# same file that script(1) is writing to (PID changes after exec).

if not set -q _MD_UNDER_SCRIPT
    if command -sq script
        set -gx _MD_LOG "$_MD_DIR/md_output.$fish_pid.log"
        set -gx _MD_UNDER_SCRIPT 1
        if test (uname) = Darwin
            exec script -q -F "$_MD_LOG" fish
        else
            exec script -q -f "$_MD_LOG" -c fish
        end
    end
    # script not found — continue without capture
end

# Use the log path passed from the bootstrap phase
set -g MD_FILE "$_MD_LOG"

set -g _MD_INIT 1
set -g _MD_LAST_CMD ""
set -g _MD_LAST_START 0
set -g _MD_LAST_END 0
set -g _MD_CURRENT_CMD ""

# ── helpers ──────────────────────────────────────────────────────────

function _md_build_exclude
    set -l user_exclude ""
    if test -f "$MD_EXCLUDE_FILE"
        set user_exclude (grep -v '^#' "$MD_EXCLUDE_FILE" 2>/dev/null | grep -v '^\s*$' | tr '\n' '|' | sed 's/|$//')
    end
    if test -n "$user_exclude"
        set -g _MD_EXCLUDE "^[[:space:]]*($_MD_DEFAULT_EXCLUDE|$user_exclude)([[:space:]]|\$)"
    else
        set -g _MD_EXCLUDE "^[[:space:]]*($_MD_DEFAULT_EXCLUDE)([[:space:]]|\$)"
    end
end

function _md_is_enabled
    if not test -f "$MD_ENABLED_FILE"
        return 0
    end
    set -l val (cat "$MD_ENABLED_FILE" 2>/dev/null)
    test "$val" != "0"
end

function _md_on
    mkdir -p (dirname "$MD_ENABLED_FILE")
    echo 1 > "$MD_ENABLED_FILE"
    echo "$MD_CMD_NAME: enabled"
end

function _md_off
    mkdir -p (dirname "$MD_ENABLED_FILE")
    echo 0 > "$MD_ENABLED_FILE"
    echo "$MD_CMD_NAME: disabled"
end

function _md_status
    if _md_is_enabled
        echo "$MD_CMD_NAME: on"
    else
        echo "$MD_CMD_NAME: off"
    end
end

function _md_filesize
    if command -sq stat
        stat -c%s "$MD_FILE" 2>/dev/null; and return
        stat -f%z "$MD_FILE" 2>/dev/null; and return
    end
    wc -c < "$MD_FILE" | string trim
end

function _md_trim_file
    test -f "$MD_FILE"; or return
    set -l size (_md_filesize)
    test "$size" -le "$_MD_MAX_SIZE"; and return
    set -l tmp "$MD_FILE.tmp"
    tail -c "$_MD_MAX_SIZE" "$MD_FILE" > "$tmp" 2>/dev/null; and mv "$tmp" "$MD_FILE"
end

function _md_clean
    perl -pe '
        # OSC: ESC ] ... (ST | BEL)  — covers title, shell integration marks, etc.
        s/\e\].*?(?:\a|\e\\|\x07)//g;
        # 8-bit OSC: 0x9D ... 0x9C
        s/\x9d.*?\x9c//g;
        # CSI: ESC [ ... final_byte
        s/\e\[[0-9;?]*[a-zA-Z@`]//g;
        # 8-bit CSI: 0x9B ... final_byte
        s/\x9b[0-9;?]*[a-zA-Z@`]//g;
        # Character set / mode: ESC ( X, ESC ) X, ESC = , ESC >
        s/\e[\(\)][A-Z0-9]//g;
        s/\e[=>]//g;
        # Any remaining bare ESC + single char
        s/\e[^\[\]0-9]//g;
        # CRLF -> LF, stray CR
        s/\r\n/\n/g;
        s/\r//g;
    ' 2>/dev/null; or cat
end

function _md_copy
    set -l input $argv[1]
    if test -z "$SSH_TTY" -a -z "$SSH_CLIENT"
        if command -q pbcopy
            printf '%s' "$input" | pbcopy; and return 0
        else if command -q xclip
            printf '%s' "$input" | xclip -selection clipboard; and return 0
        else if command -q xsel
            printf '%s' "$input" | xsel --clipboard; and return 0
        else if command -q termux-clipboard-set
            printf '%s' "$input" | termux-clipboard-set; and return 0
        end
    end
    set -l encoded (printf '%s' "$input" | base64 | tr -d '\n')
    set -l osc (printf '\033]52;c;%s\a' "$encoded")
    if test -n "$TMUX"; and command -q tmux
        tmux set-buffer -w -- "$input" >/dev/null 2>&1; and return 0
    end
    if test -n "$TMUX"
        printf '\033Ptmux;%s\033\\' "$osc"
    else
        printf '%s' "$osc"
    end
end

function _md_sed_delete
    set -l pattern $argv[1]
    set -l target $argv[2]
    test -f "$target"; or return
    if test (uname) = Darwin
        sed -i '' "$pattern" "$target" 2>/dev/null
    else
        sed -i "$pattern" "$target" 2>/dev/null
    end
end


function _md_check_update
    set -l today (date +%Y-%m-%d)
    set -l last_check ""
    if test -f "$MD_UPDATE_CHECK"
        set last_check (cat "$MD_UPDATE_CHECK" 2>/dev/null)
    end
    test "$last_check" = "$today"; and return

    mkdir -p (dirname "$MD_UPDATE_CHECK")
    echo "$today" > "$MD_UPDATE_CHECK"

    set -l remote_version (curl -fsSL --connect-timeout 2 "$MD_RAW_URL/$MD_UPDATE_TARGET" 2>/dev/null \
        | grep '^set -g MD_VERSION' | head -1 \
        | string match -r '"([^"]+)"')
    set remote_version $remote_version[2]

    if test -n "$remote_version" -a "$remote_version" != "$MD_VERSION"
        echo "$MD_CMD_NAME: new version available ($MD_VERSION -> $remote_version)"
        echo "    run '$MD_CMD_NAME update' to upgrade"
    end
end

function _md_update
    echo "Updating $MD_CMD_NAME..."
    curl -fsSL "$MD_RAW_URL/install-online.sh" | MD_CMD_NAME="$MD_CMD_NAME" bash
end

function _md_uninstall
    echo "Uninstalling $MD_CMD_NAME..."
    _md_sed_delete '/md\.fish/d' "$MD_RC_FILE"
    _md_sed_delete '/md - copy last command/d' "$MD_RC_FILE"
    _md_sed_delete '/MD_CMD_NAME/d' "$MD_RC_FILE"
    rm -rf "$HOME/.md"
    rm -f "$_MD_DIR"/md_output.* 2>/dev/null
    echo "Done. Restart shell."
end

function _md_exclude_add
    set -l cmd $argv[1]
    if test -z "$cmd"
        echo "usage: $MD_CMD_NAME exclude add <command>" >&2; return 1
    end
    mkdir -p (dirname "$MD_EXCLUDE_FILE")
    if grep -qxF "$cmd" "$MD_EXCLUDE_FILE" 2>/dev/null
        echo "'$cmd' already excluded"
    else
        echo "$cmd" >> "$MD_EXCLUDE_FILE"
        _md_build_exclude
        echo "added '$cmd' to exclude list"
    end
end

function _md_exclude_rm
    set -l cmd $argv[1]
    if test -z "$cmd"
        echo "usage: $MD_CMD_NAME exclude rm <command>" >&2; return 1
    end
    if not test -f "$MD_EXCLUDE_FILE"
        echo "'$cmd' not in user exclude list"; return 1
    end
    if grep -qxF "$cmd" "$MD_EXCLUDE_FILE" 2>/dev/null
        set -l tmp (mktemp "$MD_EXCLUDE_FILE.XXXXXX"); or return 1
        grep -vxF "$cmd" "$MD_EXCLUDE_FILE" > "$tmp" 2>/dev/null; or true
        mv "$tmp" "$MD_EXCLUDE_FILE"
        _md_build_exclude
        echo "removed '$cmd' from exclude list"
    else
        echo "'$cmd' not in user exclude list"; return 1
    end
end

function _md_exclude_list
    echo "Default excluded commands:"
    echo "$_MD_DEFAULT_EXCLUDE" | tr '|' '\n' | sed 's/^/  /'
    echo ""
    if test -f "$MD_EXCLUDE_FILE" -a -s "$MD_EXCLUDE_FILE"
        echo "User excluded commands (~/.md/exclude):"
        grep -v '^#' "$MD_EXCLUDE_FILE" | grep -v '^\s*$' | sed 's/^/  /'
    else
        echo "User excluded commands: (none)"
    end
end

function _md_help
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
end


# ── main command ─────────────────────────────────────────────────────

function _md_main
    switch "$argv[1]"
        case on;        _md_on;        return
        case off;       _md_off;       return
        case status;    _md_status;    return
        case update;    _md_update;    return
        case uninstall; _md_uninstall; return
        case version -v --version
            echo "$MD_CMD_NAME $MD_VERSION"; return
        case exclude
            switch "$argv[2]"
                case add;           _md_exclude_add "$argv[3]"
                case rm remove;     _md_exclude_rm "$argv[3]"
                case list ls '';    _md_exclude_list
                case '*'
                    echo "usage: $MD_CMD_NAME exclude [add|rm|list] [command]" >&2; return 1
            end
            return
        case help -h --help
            _md_help; return
    end

    # Default action: copy last command + output
    if not _md_is_enabled
        echo "$MD_CMD_NAME: disabled (run '$MD_CMD_NAME on' to enable)" >&2
        return 1
    end

    if test -z "$_MD_LAST_CMD"
        echo "no record" >&2
        return 1
    end

    set -l start $_MD_LAST_START
    set -l end   $_MD_LAST_END
    set -l count (math "$end - $start")

    set -l content "\$ $_MD_LAST_CMD"

    if test "$count" -gt 0
        set -l output (dd if="$MD_FILE" bs=1 skip="$start" count="$count" status=none 2>/dev/null | _md_clean)
        set content "$content
$output"
    end

    _md_copy "$content"; and echo "copied"
end

# ── event hooks ──────────────────────────────────────────────────────

_md_build_exclude

function _md_fish_preexec --on-event fish_preexec
    _md_is_enabled; or return

    set -l cmd $argv[1]
    echo "$cmd" | command grep -qE "$_MD_EXCLUDE"; and return

    set -g _MD_CURRENT_CMD "$cmd"
    set -g _MD_CMD_START (_md_filesize)
end

function _md_fish_postexec --on-event fish_postexec
    test -n "$_MD_CURRENT_CMD"; or return

    # Small delay for script(1) to flush
    command sleep 0.02 2>/dev/null

    set -g _MD_LAST_CMD "$_MD_CURRENT_CMD"
    set -g _MD_LAST_START "$_MD_CMD_START"
    set -g _MD_LAST_END (_md_filesize)
    set -g _MD_CURRENT_CMD ""

    _md_trim_file
end

# ── cleanup on exit ──────────────────────────────────────────────────

function _md_fish_exit --on-event fish_exit
    rm -f "$MD_FILE" 2>/dev/null
end

# ── register command ─────────────────────────────────────────────────

function $MD_CMD_NAME --description "copy last command and output to clipboard"
    _md_main $argv
end

# ── background update check ──────────────────────────────────────────
fish -c '_md_check_update' &>/dev/null &
disown 2>/dev/null; or true
