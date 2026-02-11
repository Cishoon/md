#!/bin/zsh
# md - copy last command and output to clipboard (zsh adapter)

# Command name: configurable via MD_CMD_NAME (default: md)
: "${MD_CMD_NAME:=md}"

# JetBrains terminal is not supported.
if [[ "$TERMINAL_EMULATOR" == *"JetBrains"* ]]; then
    unalias "$MD_CMD_NAME" >/dev/null 2>&1 || true
    eval "function ${MD_CMD_NAME}() { echo \"$MD_CMD_NAME: not supported in JetBrains terminal\" >&2; return 1; }"
    return 0
fi

MD_SHELL_NAME="zsh"
MD_UPDATE_TARGET="md.zsh"
MD_RC_FILE="$HOME/.zshrc"

_md_script_dir="${${(%):-%N}:A:h}"
if [[ ! -f "$_md_script_dir/md.core.sh" ]]; then
    echo "$MD_CMD_NAME: missing core script ($_md_script_dir/md.core.sh)" >&2
    return 1
fi

# shellcheck source=/dev/null
source "$_md_script_dir/md.core.sh"

if [[ -z "$_MD_INIT" ]]; then
    _MD_INIT=1
    _MD_CURRENT_CMD=""

    _md_init_shared

    autoload -Uz add-zsh-hook

    _md_preexec() {
        _md_is_enabled || return

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

# Check for updates daily (background, non-blocking)
(_md_check_update &) 2>/dev/null

_md_register_command
