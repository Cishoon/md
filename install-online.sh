#!/bin/bash
# md online installer
# Usage: curl -fsSL https://raw.githubusercontent.com/Cishoon/md/main/install-online.sh | bash
# Or:    curl -fsSL https://raw.githubusercontent.com/Cishoon/md/main/install-online.sh | MD_CMD_NAME=mdd bash

set -e

REPO="Cishoon/md"
INSTALL_DIR="$HOME/.md"
RAW_URL="https://raw.githubusercontent.com/$REPO/main"

# Use MD_CMD_NAME env var if set, otherwise default to "md"
CMD_NAME="${MD_CMD_NAME:-md}"

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

get_rc_file() {
    case "$(detect_shell)" in
        zsh) echo "$HOME/.zshrc" ;;
        *) echo "$HOME/.bashrc" ;;
    esac
}

main() {
    local shell_type rc_file
    shell_type="$(detect_shell)"
    rc_file="$(get_rc_file)"
    
    echo "Installing md (command: $CMD_NAME)..."
    echo "Shell: $shell_type"
    echo ""
    
    mkdir -p "$INSTALL_DIR"
    
    # Download shared core + shell adapter
    local shell_script
    if [[ "$shell_type" == "zsh" ]]; then
        shell_script="md.zsh"
    else
        shell_script="md.bash"
    fi

    curl -fsSL "$RAW_URL/md.core.sh" -o "$INSTALL_DIR/md.core.sh"
    curl -fsSL "$RAW_URL/$shell_script" -o "$INSTALL_DIR/md.sh"
    chmod +x "$INSTALL_DIR/md.sh" "$INSTALL_DIR/md.core.sh"
    
    # Add to shell config
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
    
    echo ""
    echo "Done!"
    echo ""
    echo "Run: source $rc_file"
    echo "Then type any command, and use '$CMD_NAME' to copy it."
}

main
