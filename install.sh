#!/bin/bash
# md installer - auto detect platform and shell

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.md"
CMD_NAME="md"  # default command name

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --cmd=*)
            CMD_NAME="${arg#*=}"
            ;;
        install|uninstall)
            ACTION="$arg"
            ;;
    esac
done
ACTION="${ACTION:-install}"

detect_shell() {
    # FISH_VERSION is exported by fish into child processes
    if [[ -n "$FISH_VERSION" ]]; then
        echo "fish"
        return
    fi

    # Check parent process name (covers interactive invocation from fish)
    local parent_name=""
    if [[ -f /proc/$PPID/comm ]]; then
        parent_name=$(cat /proc/$PPID/comm 2>/dev/null)
    elif command -v ps &>/dev/null; then
        parent_name=$(ps -p "$PPID" -o comm= 2>/dev/null)
    fi
    case "$parent_name" in
        fish|*/fish) echo "fish"; return ;;
    esac

    # Fall back to $SHELL (login shell)
    case "$SHELL" in
        */zsh) echo "zsh" ;;
        */fish) echo "fish" ;;
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
        fish) echo "$HOME/.config/fish/config.fish" ;;
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
    echo "Command: $CMD_NAME"
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
    
    cp "$SCRIPT_DIR/md.core.sh" "$INSTALL_DIR/md.core.sh"
    if [[ "$shell_type" == "fish" ]]; then
        cp "$SCRIPT_DIR/md.fish" "$INSTALL_DIR/md.fish"
        chmod +x "$INSTALL_DIR/md.fish"
    elif [[ "$shell_type" == "zsh" ]]; then
        cp "$SCRIPT_DIR/md.zsh" "$INSTALL_DIR/md.sh"
        chmod +x "$INSTALL_DIR/md.sh" "$INSTALL_DIR/md.core.sh"
    else
        cp "$SCRIPT_DIR/md.bash" "$INSTALL_DIR/md.sh"
        chmod +x "$INSTALL_DIR/md.sh" "$INSTALL_DIR/md.core.sh"
    fi
    
    if [[ "$shell_type" == "fish" ]]; then
        mkdir -p "$(dirname "$rc_file")"
        if grep -q '\.md/md\.fish' "$rc_file" 2>/dev/null; then
            echo "md already configured in $rc_file"
        else
            cat >> "$rc_file" << EOF

# md - copy last command to clipboard
set -g MD_CMD_NAME "$CMD_NAME"
source "\$HOME/.md/md.fish"
EOF
            echo "Added to $rc_file"
        fi
    else
        if grep -q '\.md/md\.sh' "$rc_file" 2>/dev/null; then
            echo "md already configured in $rc_file"
        else
            cat >> "$rc_file" << EOF

# md - copy last command to clipboard
MD_CMD_NAME="$CMD_NAME"
source "\$HOME/.md/md.sh"
EOF
            echo "Added to $rc_file"
        fi
    fi
    
    echo ""
    echo "Done!"
    echo ""
    echo "Run: source $rc_file"
    echo "Usage: run any command, then type '$CMD_NAME' to copy"
    echo "Uninstall: $SCRIPT_DIR/install.sh uninstall"
}

uninstall() {
    local rc_file
    rc_file="$(get_rc_file)"
    
    echo "Uninstalling..."
    
    if [[ -f "$rc_file" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' '/\.md\/md\.\(sh\|fish\)/d' "$rc_file"
            sed -i '' '/md - copy last command/d' "$rc_file"
            sed -i '' '/MD_CMD_NAME/d' "$rc_file"
        else
            sed -i '/\.md\/md\.\(sh\|fish\)/d' "$rc_file"
            sed -i '/md - copy last command/d' "$rc_file"
            sed -i '/MD_CMD_NAME/d' "$rc_file"
        fi
        echo "Removed from $rc_file"
    fi
    
    rm -rf "$INSTALL_DIR"
    rm -rf "${TMPDIR:-/tmp}/md-"*
    rm -f "${TMPDIR:-/tmp}/.md_output_"*
    
    echo ""
    echo "Done! Restart terminal to take effect."
}

case "$ACTION" in
    install) install ;;
    uninstall) uninstall ;;
    *) echo "Usage: $0 [install|uninstall] [--cmd=md|mdd]" ;;
esac
