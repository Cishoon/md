#!/bin/bash
# md - copy last command and output to clipboard (bash adapter)

[[ $- != *i* ]] && return

# Command name: configurable via MD_CMD_NAME (default: md)
: "${MD_CMD_NAME:=md}"

# JetBrains terminal is not supported.
if [[ "$TERMINAL_EMULATOR" == *"JetBrains"* ]]; then
    unalias "$MD_CMD_NAME" >/dev/null 2>&1 || true
    eval "function ${MD_CMD_NAME}() { echo \"$MD_CMD_NAME: not supported in JetBrains terminal\" >&2; return 1; }"
    return 0
fi

MD_SHELL_NAME="bash"
MD_UPDATE_TARGET="md.bash"
MD_RC_FILE="$HOME/.bashrc"

_md_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$_md_script_dir/md.core.sh" ]]; then
    echo "$MD_CMD_NAME: missing core script ($_md_script_dir/md.core.sh)" >&2
    return 1
fi

# shellcheck source=/dev/null
source "$_md_script_dir/md.core.sh"

if [[ -z "$_MD_INIT" ]]; then
    _MD_INIT=1
    _MD_CURRENT_CMD=""
    _MD_CAPTURE_ACTIVE=0
    _MD_READY=0

    _md_init_shared

    _md_mark_prompt() {
        _MD_READY=1
    }

    _md_debug() {
        [[ $_MD_READY -eq 1 ]] || return 0
        _MD_READY=0

        _md_is_enabled || return 0

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

# Check for updates daily (background, non-blocking)
(_md_check_update &) 2>/dev/null

_md_register_command
