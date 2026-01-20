#!/bin/bash
# md - copy last command and output to clipboard

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
    if command -v pbcopy &>/dev/null; then
        pbcopy
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard
    elif command -v xsel &>/dev/null; then
        xsel --clipboard --input
    elif command -v clip.exe &>/dev/null; then
        clip.exe
    else
        echo "no clipboard tool found" >&2
        return 1
    fi
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

md() {
    [[ -z "$_md_last_cmd" ]] && { echo "no record" >&2; return 1; }
    
    local len=$(( _md_last_end - _md_last_start ))
    local output=""
    (( len > 0 )) && output=$(dd if="$MD_LOG" bs=1 skip="$_md_last_start" count="$len" 2>/dev/null)
    
    {
        echo "$ $_md_last_cmd"
        echo "$output" | _md_clean
    } | _md_copy && echo "copied"
}
