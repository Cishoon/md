#!/bin/bash
# md installer - auto detect platform and shell

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.md"

detect_shell() {
    case "$SHELL" in
        */zsh) echo "zsh" ;;
        */bash) echo "bash" ;;
        *) 
            if [[ -n "$ZSH_VERSION" ]]; then
                echo "zsh"
            else
                echo "bash"
            fi
            ;;
    esac
}

detect_platform() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux) 
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

get_rc_file() {
    case "$(detect_shell)" in
        zsh) echo "$HOME/.zshrc" ;;
        *) echo "$HOME/.bashrc" ;;
    esac
}

check_clipboard() {
    local platform="$(detect_platform)"
    case "$platform" in
        macos)
            command -v pbcopy &>/dev/null && return 0
            ;;
        linux|wsl)
            command -v xclip &>/dev/null && return 0
            command -v xsel &>/dev/null && return 0
            ;;
        windows)
            command -v clip.exe &>/dev/null && return 0
            ;;
    esac
    return 1
}

install() {
    local shell_type rc_file platform
    shell_type="$(detect_shell)"
    rc_file="$(get_rc_file)"
    platform="$(detect_platform)"
    
    echo "Platform: $platform"
    echo "Shell: $shell_type"
    echo "Config: $rc_file"
    echo ""
    
    if ! check_clipboard; then
        echo "Warning: no clipboard tool found"
        case "$platform" in
            linux) echo "  Install: sudo apt install xclip" ;;
        esac
        echo ""
    fi
    
    echo "Installing..."
    mkdir -p "$INSTALL_DIR"
    
    if [[ "$shell_type" == "zsh" ]]; then
        cp "$SCRIPT_DIR/md.zsh" "$INSTALL_DIR/md.sh"
    else
        cp "$SCRIPT_DIR/md.bash" "$INSTALL_DIR/md.sh"
    fi
    chmod +x "$INSTALL_DIR/md.sh"
    
    if grep -q '\.md/md\.sh' "$rc_file" 2>/dev/null; then
        echo "md already configured in $rc_file"
    else
        cat >> "$rc_file" << 'EOF'

# md - copy last command to clipboard
source "$HOME/.md/md.sh"
EOF
        echo "Added to $rc_file"
    fi
    
    echo ""
    echo "Done!"
    echo ""
    echo "Run: source $rc_file"
    echo "Usage: run any command, then type 'md' to copy"
    echo "Uninstall: $SCRIPT_DIR/install.sh uninstall"
}

uninstall() {
    local rc_file
    rc_file="$(get_rc_file)"
    
    echo "Uninstalling..."
    
    if [[ -f "$rc_file" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' '/\.md\/md\.sh/d' "$rc_file"
            sed -i '' '/md - copy last command/d' "$rc_file"
        else
            sed -i '/\.md\/md\.sh/d' "$rc_file"
            sed -i '/md - copy last command/d' "$rc_file"
        fi
        echo "Removed from $rc_file"
    fi
    
    rm -rf "$INSTALL_DIR"
    rm -rf "${TMPDIR:-/tmp}/md-"*
    rm -f "${TMPDIR:-/tmp}/.md_output_"*
    
    echo ""
    echo "Done! Restart terminal to take effect."
}

case "${1:-install}" in
    install) install ;;
    uninstall) uninstall ;;
    *) echo "Usage: $0 [install|uninstall]" ;;
esac
