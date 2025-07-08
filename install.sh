#!/bin/bash

# UVM (Urbit Version Manager) Install Script
# This script installs uvm and sets up shell integration

set -e

# Default settings
UVM_HOME="${UVM_HOME:-$HOME/.uvm}"
UVM_SCRIPT_URL="https://raw.githubusercontent.com/labwet/uvm/main/uvm.sh"
UVM_SCRIPT_PATH="$UVM_HOME/uvm.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[UVM]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[UVM]${NC} $1" >&2
}

error() {
    echo -e "${RED}[UVM]${NC} $1" >&2
}

# Detect shell
detect_shell() {
    local shell_name
    shell_name=$(basename "$SHELL")
    
    case "$shell_name" in
        bash)
            echo "bash"
            ;;
        zsh)
            echo "zsh"
            ;;
        fish)
            echo "fish"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get shell profile file
get_shell_profile() {
    local shell_name="$1"
    
    case "$shell_name" in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        zsh)
            echo "$HOME/.zshrc"
            ;;
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Check if uvm is already installed
check_existing_installation() {
    if [ -f "$UVM_SCRIPT_PATH" ]; then
        warn "UVM is already installed at $UVM_SCRIPT_PATH"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation cancelled"
            exit 0
        fi
    fi
}

# Create UVM directory structure
create_uvm_directories() {
    log "Creating UVM directory structure..."
    mkdir -p "$UVM_HOME"
    mkdir -p "$UVM_HOME/versions"
    mkdir -p "$UVM_HOME/aliases"
}

# Download or copy UVM script
install_uvm_script() {
    log "Installing UVM script..."
    
    # For development/local install, copy from current directory
    if [ -f "./uvm.sh" ]; then
        cp "./uvm.sh" "$UVM_SCRIPT_PATH"
        log "Copied uvm.sh to $UVM_SCRIPT_PATH"
    else
        # For production, download from GitHub
        if command -v curl >/dev/null 2>&1; then
            curl -o "$UVM_SCRIPT_PATH" "$UVM_SCRIPT_URL"
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$UVM_SCRIPT_PATH" "$UVM_SCRIPT_URL"
        else
            error "Neither curl nor wget found. Cannot download UVM script."
            exit 1
        fi
        log "Downloaded UVM script to $UVM_SCRIPT_PATH"
    fi
    
    chmod +x "$UVM_SCRIPT_PATH"
}

# Setup shell integration
setup_shell_integration() {
    local shell_name profile_file
    
    shell_name=$(detect_shell)
    profile_file=$(get_shell_profile "$shell_name")
    
    log "Setting up shell integration for $shell_name..."
    
    if [ -z "$profile_file" ]; then
        warn "Unknown shell: $shell_name"
        warn "You'll need to manually add UVM to your shell configuration"
        show_manual_setup_instructions
        return
    fi
    
    # Create profile file if it doesn't exist
    if [ ! -f "$profile_file" ]; then
        touch "$profile_file"
        log "Created $profile_file"
    fi
    
    # Check if UVM is already in the profile
    if grep -q "# UVM (Urbit Version Manager)" "$profile_file"; then
        log "UVM configuration already exists in $profile_file"
        return 0
    fi
    
    # Add UVM configuration based on shell
    case "$shell_name" in
        bash|zsh)
            cat >> "$profile_file" << EOF

# UVM (Urbit Version Manager)
export UVM_HOME="$UVM_HOME"
[ -s "\$UVM_HOME/uvm.sh" ] && source "\$UVM_HOME/uvm.sh"

# Explicitly add UVM current to PATH if it exists
if [ -L "\$UVM_HOME/current" ] && [ -d "\$UVM_HOME/current" ]; then
    export PATH="\$UVM_HOME/current:\$PATH"
fi
EOF
            ;;
        fish)
            # Fish shell has different syntax
            cat >> "$profile_file" << EOF

# UVM (Urbit Version Manager)
set -gx UVM_HOME "$UVM_HOME"
[ -s "\$UVM_HOME/uvm.sh" ] && source "\$UVM_HOME/uvm.sh"

# Add UVM current version to PATH
if test -L "\$UVM_HOME/current"
    set -gx PATH "\$UVM_HOME/current" \$PATH
end
EOF
            ;;
    esac
    
    log "Added UVM configuration to $profile_file"
}

# Show manual setup instructions
show_manual_setup_instructions() {
    log "Manual setup instructions:"
    echo "Add the following to your shell profile:"
    echo ""
    echo "export UVM_HOME=\"$UVM_HOME\""
    echo "[ -s \"\$UVM_HOME/uvm.sh\" ] && source \"\$UVM_HOME/uvm.sh\""
    echo ""
    echo "# Add UVM current version to PATH"
    echo "if [ -L \"\$UVM_HOME/current\" ]; then"
    echo "    export PATH=\"\$UVM_HOME/current:\$PATH\""
    echo "fi"
}

# Create uvm command wrapper
create_uvm_command() {
    local uvm_wrapper_path="/usr/local/bin/uvm"
    
    # Try to create /usr/local/bin if it doesn't exist
    if [ ! -d "/usr/local/bin" ]; then
        if sudo mkdir -p "/usr/local/bin" 2>/dev/null; then
            log "Created /usr/local/bin directory"
        else
            warn "Cannot create /usr/local/bin directory"
            return 1
        fi
    fi
    
    # Check if we can write to /usr/local/bin
    if [ -w "/usr/local/bin" ] || sudo test -w "/usr/local/bin" 2>/dev/null; then
        log "Creating uvm command wrapper..."
        
        # Create wrapper script
        local wrapper_content="#!/bin/bash
exec \"$UVM_SCRIPT_PATH\" \"\$@\""
        
        if [ -w "/usr/local/bin" ]; then
            echo "$wrapper_content" > "$uvm_wrapper_path"
            chmod +x "$uvm_wrapper_path"
        else
            echo "$wrapper_content" | sudo tee "$uvm_wrapper_path" > /dev/null
            sudo chmod +x "$uvm_wrapper_path"
        fi
        
        log "Created uvm command at $uvm_wrapper_path"
        return 0
    else
        warn "Cannot write to /usr/local/bin"
        warn "Adding alias to shell profile instead..."
        add_alias_to_profile
        return 1
    fi
}

# Add alias to shell profile
add_alias_to_profile() {
    local shell_name profile_file
    
    shell_name=$(detect_shell)
    profile_file=$(get_shell_profile "$shell_name")
    
    if [ -n "$profile_file" ]; then
        # Check if alias already exists
        if ! grep -q "alias uvm=" "$profile_file" 2>/dev/null; then
            echo "" >> "$profile_file"
            echo "# UVM alias" >> "$profile_file"
            echo "alias uvm='$UVM_SCRIPT_PATH'" >> "$profile_file"
            log "Added uvm alias to $profile_file"
        else
            log "UVM alias already exists in $profile_file"
        fi
    else
        warn "Could not determine shell profile. Please manually add:"
        warn "  alias uvm='$UVM_SCRIPT_PATH'"
    fi
}

# Main installation function
main() {
    log "Starting UVM installation..."
    
    # Allow user to specify custom UVM_HOME
    if [ -n "$1" ]; then
        UVM_HOME="$1"
        UVM_SCRIPT_PATH="$UVM_HOME/uvm.sh"
        log "Using custom UVM_HOME: $UVM_HOME"
    fi
    
    check_existing_installation
    create_uvm_directories
    install_uvm_script
    setup_shell_integration
    
    # Try to create uvm command wrapper
    if ! create_uvm_command; then
        log "UVM installation completed!"
        log "UVM alias has been added to your shell profile."
        log "To use UVM immediately, run:"
        log "  source ~/.zshrc     # for zsh"
        log "  source ~/.bashrc    # for bash"
        log "Or restart your terminal and then run 'uvm help' to get started"
    else
        log "UVM installation completed!"
        log "Please restart your shell or run: source ~/.zshrc (or your shell profile)"
        log "Then you can use 'uvm help' to get started"
    fi
}

# Run main installation
main "$@"