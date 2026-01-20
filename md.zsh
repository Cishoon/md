#!/bin/zsh
# md - copy last command and output to clipboard

MD_FILE="${TMPDIR:-/tmp}/.md_output_$$"

if [[ -z "$_MD_INIT" ]]; then
    _MD_INIT=1
    _MD_LAST_CMD=""
    _MD_LAST_OUTPUT=""
    _MD_EXCLUDE='^[[:space:]]*(md|clear|reset|exit|cd|pwd|history|fg|bg|vim|vi|nano|less|more|top|htop|man|ssh|sudo)([[:space:]]|$)'
    
    autoload -Uz add-zsh-hook
    
    _md_preexec() {
        local cmd="$1"
        # 排除 md 和其他命令
        [[ "$cmd" =~ $_MD_EXCLUDE ]] && return
        
        _MD_CURRENT_CMD="$cmd"
        exec 3>&1 4>&2
        exec > >(tee "$MD_FILE") 2>&1
    }
    
    _md_precmd() {
        # 如果没有当前命令，跳过
        [[ -z "$_MD_CURRENT_CMD" ]] && return
        
        # 恢复输出
        exec 1>&3 2>&4 3>&- 4>&-
        
        # 保存为"上一条命令"供 md 使用
        _MD_LAST_CMD="$_MD_CURRENT_CMD"
        _MD_CURRENT_CMD=""
    }
    
    add-zsh-hook preexec _md_preexec
    add-zsh-hook precmd _md_precmd
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

md() {
    if [[ -z "$_MD_LAST_CMD" ]] || [[ ! -s "$MD_FILE" ]]; then
        echo "no record" >&2
        return 1
    fi
    
    {
        echo "$ $_MD_LAST_CMD"
        cat "$MD_FILE" 2>/dev/null | _md_clean
    } | _md_copy && echo "copied"
}
