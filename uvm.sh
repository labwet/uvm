#!/bin/bash

# UVM (Urbit Version Manager)
# A POSIX-compliant tool for managing urbit/vere versions

# Constants
UVM_VERSION="1.0.0"
UVM_HOME="${UVM_HOME:-$HOME/.uvm}"
UVM_VERSIONS_DIR="$UVM_HOME/versions"
UVM_CURRENT_LINK="$UVM_HOME/current"
UVM_ALIASES_DIR="$UVM_HOME/aliases"
UVM_DEFAULT_FILE="$UVM_HOME/default"
VERE_REPO="urbit/vere"
GITHUB_API_URL="https://api.github.com/repos/$VERE_REPO/releases"

# Core functions (to be implemented)
uvm_help() {
    cat << 'EOF'
UVM (Urbit Version Manager) - Manage urbit/vere versions

Usage:
  uvm                           Show this help
  uvm install <version>         Install specific version
  uvm install                   Install from .uvmrc
  uvm use <version>             Switch to version
  uvm use                       Switch to .uvmrc version
  uvm current                   Show active version
  uvm ls                        List installed versions
  uvm ls-remote                 List available remote versions
  uvm uninstall <version>       Remove version
  uvm nuke                      Remove UVM and all its artifacts
  uvm run <version> [args]      Run urbit with specific version
  uvm exec <version> <command>  Execute command with version in PATH
  uvm default <version>         Set global default version
  uvm which <version>           Show path to version
  uvm alias <name> <version>    Create alias
  uvm unalias <name>            Remove alias
  uvm version                   Show uvm version
  uvm help                      Show this help

Examples:
  uvm install vere-v3.4         Install vere version 3.4
  uvm use vere-v3.4             Switch to vere version 3.4
  uvm run vere-v3.4 --help      Run urbit v3.4 with --help
  uvm ls-remote                 List all available versions
EOF
}

uvm_version() {
    echo "$UVM_VERSION"
}

uvm_detect_platform() {
    local os arch platform architecture
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    
    case "$os" in
        linux*) platform="linux" ;;
        darwin*) platform="macos" ;;
        *) 
            echo "Error: Unsupported platform: $os" >&2
            exit 1
            ;;
    esac
    
    case "$arch" in
        x86_64|amd64) architecture="x86_64" ;;
        arm64|aarch64) architecture="aarch64" ;;
        *)
            echo "Error: Unsupported architecture: $arch" >&2
            exit 1
            ;;
    esac
    
    echo "${platform}-${architecture}"
}

uvm_ensure_dirs() {
    mkdir -p "$UVM_VERSIONS_DIR"
    mkdir -p "$UVM_ALIASES_DIR"
}

uvm_fetch_releases() {
    local response
    
    if command -v curl >/dev/null 2>&1; then
        response=$(curl -s "$GITHUB_API_URL")
    elif command -v wget >/dev/null 2>&1; then
        response=$(wget -qO- "$GITHUB_API_URL")
    else
        echo "Error: Neither curl nor wget found" >&2
        exit 1
    fi
    
    # Basic validation that we got JSON
    if echo "$response" | grep -q "\"tag_name\""; then
        echo "$response"
    else
        echo "Error: Invalid response from GitHub API" >&2
        if echo "$response" | grep -q "rate limit"; then
            echo "Error: GitHub API rate limit exceeded" >&2
        fi
        exit 1
    fi
}

uvm_parse_version() {
    local version="$1"
    local alias_file
    
    # Check if it's an alias first
    alias_file="$UVM_ALIASES_DIR/$version"
    if [ -f "$alias_file" ]; then
        version=$(cat "$alias_file")
    fi
    
    # Handle various version formats
    case "$version" in
        vere-v*) echo "$version" ;;
        v*) echo "vere-$version" ;;
        *) echo "vere-v$version" ;;
    esac
}

uvm_install() {
    local version="$1"
    local platform_arch asset_url download_url version_dir
    
    if [ -z "$version" ]; then
        version=$(uvm_read_uvmrc)
        if [ -z "$version" ]; then
            echo "Error: No version specified and no .uvmrc found" >&2
            exit 1
        fi
    fi
    
    version=$(uvm_parse_version "$version")
    platform_arch=$(uvm_detect_platform)
    version_dir="$UVM_VERSIONS_DIR/$version"
    
    # Check if version already installed
    if [ -d "$version_dir" ]; then
        echo "$version is already installed"
        return 0
    fi
    
    uvm_ensure_dirs
    
    echo "Installing $version for $platform_arch..."
    
    # Get release information
    local releases_json
    releases_json=$(uvm_fetch_releases)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch releases from GitHub" >&2
        exit 1
    fi
    
    # Find the download URL for the specific version and platform
    # Try jq first if available, otherwise use grep/sed
    if command -v jq >/dev/null 2>&1; then
        download_url=$(echo "$releases_json" | jq -r ".[] | select(.tag_name == \"$version\") | .assets[] | select(.name | contains(\"$platform_arch\")) | .browser_download_url" | head -1)
    else
        # Fallback to grep/sed approach - look for the entire release block
        download_url=$(echo "$releases_json" | \
            sed -n "/\"tag_name\":[[:space:]]*\"$version\"/,/\"tag_name\":[[:space:]]*\"/p" | \
            grep "\"browser_download_url\":" | \
            grep "$platform_arch" | \
            sed 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/' | \
            head -1)
    fi
    
    # Debug output
    if [ -z "$download_url" ]; then
        echo "Debug: version=$version, platform_arch=$platform_arch" >&2
        echo "Debug: Checking if version exists in releases..." >&2
        if echo "$releases_json" | grep -q "\"tag_name\":[[:space:]]*\"$version\""; then
            echo "Debug: Version found in releases" >&2
        else
            echo "Debug: Version NOT found in releases" >&2
        fi
    fi
    
    if [ -z "$download_url" ]; then
        echo "Error: No binary found for $version on $platform_arch" >&2
        exit 1
    fi
    
    echo "Downloading from: $download_url"
    
    # Create temporary directory for download
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Download and extract
    if command -v curl >/dev/null 2>&1; then
        if ! curl -L "$download_url" -o "$temp_dir/vere.tgz"; then
            echo "Error: Failed to download $version" >&2
            rm -rf "$temp_dir"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if ! wget -O "$temp_dir/vere.tgz" "$download_url"; then
            echo "Error: Failed to download $version" >&2
            rm -rf "$temp_dir"
            exit 1
        fi
    else
        echo "Error: Neither curl nor wget found" >&2
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Validate download
    if [ ! -f "$temp_dir/vere.tgz" ] || [ ! -s "$temp_dir/vere.tgz" ]; then
        echo "Error: Downloaded file is empty or missing" >&2
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Extract to version directory
    mkdir -p "$version_dir"
    if ! tar -xzf "$temp_dir/vere.tgz" -C "$version_dir" 2>/dev/null; then
        echo "Error: Failed to extract $version" >&2
        rm -rf "$temp_dir" "$version_dir"
        exit 1
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    # Make binary executable
    chmod +x "$version_dir"/*
    
    # Validate installation and create urbit symlink
    local vere_binary
    vere_binary=$(find "$version_dir" -name "vere*" -type f -perm +111 | head -1)
    
    if [ -z "$vere_binary" ]; then
        echo "Error: vere binary not found after installation" >&2
        rm -rf "$version_dir"
        exit 1
    fi
    
    # Create urbit symlink for the binary
    ln -sf "$(basename "$vere_binary")" "$version_dir/urbit"
    
    # Also create a vere symlink for compatibility
    ln -sf "$(basename "$vere_binary")" "$version_dir/vere"
    
    # Test that binary works
    if ! "$vere_binary" --help >/dev/null 2>&1; then
        echo "Warning: vere binary may not be functional" >&2
    fi
    
    echo "Successfully installed $version"
}

uvm_use() {
    local version="$1"
    local version_dir
    
    if [ -z "$version" ]; then
        version=$(uvm_read_uvmrc)
        if [ -z "$version" ]; then
            echo "Error: No version specified and no .uvmrc found" >&2
            exit 1
        fi
    fi
    
    version=$(uvm_parse_version "$version")
    version_dir="$UVM_VERSIONS_DIR/$version"
    
    # Check if version is installed
    if [ ! -d "$version_dir" ]; then
        echo "Error: $version is not installed" >&2
        echo "Run 'uvm install $version' to install it" >&2
        exit 1
    fi
    
    # Create or update the current symlink
    rm -f "$UVM_CURRENT_LINK"
    ln -s "$version_dir" "$UVM_CURRENT_LINK"
    
    # Update PATH for current session
    if [ -n "$BASH_VERSION" ] || [ -n "$ZSH_VERSION" ]; then
        # Remove old UVM paths
        PATH=$(echo "$PATH" | sed -E "s|:?$UVM_HOME/current[^:]*:?||g")
        PATH=$(echo "$PATH" | sed -E "s|^:||")
        
        # Add new path
        export PATH="$UVM_CURRENT_LINK:$PATH"
    fi
    
    echo "Now using $version"
}

uvm_current_version() {
    # Check if there's a current symlink
    if [ -L "$UVM_CURRENT_LINK" ]; then
        basename "$(readlink "$UVM_CURRENT_LINK")"
    elif [ -f "$UVM_DEFAULT_FILE" ]; then
        cat "$UVM_DEFAULT_FILE"
    else
        echo ""
    fi
}

uvm_current() {
    local current_version
    current_version=$(uvm_current_version)
    
    if [ -n "$current_version" ]; then
        echo "$current_version"
    else
        echo "No version currently in use"
    fi
}

uvm_ls() {
    local current_version
    
    if [ ! -d "$UVM_VERSIONS_DIR" ]; then
        echo "No versions installed"
        return 0
    fi
    
    current_version=$(uvm_current_version)
    
    for version_dir in "$UVM_VERSIONS_DIR"/*; do
        if [ -d "$version_dir" ]; then
            local version
            version=$(basename "$version_dir")
            
            if [ "$version" = "$current_version" ]; then
                echo "* $version"
            else
                echo "  $version"
            fi
        fi
    done | sort -V
}

uvm_ls_remote() {
    local releases_json version
    
    echo "Fetching available versions..."
    releases_json=$(uvm_fetch_releases)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch releases from GitHub" >&2
        exit 1
    fi
    
    # Parse JSON to extract tag names
    echo "$releases_json" | grep -o '"tag_name":[[:space:]]*"[^"]*"' | \
        cut -d'"' -f4 | \
        sort -V -r
}

uvm_uninstall() {
    local version="$1"
    local version_dir current_version
    
    if [ -z "$version" ]; then
        echo "Error: Version required" >&2
        exit 1
    fi
    
    version=$(uvm_parse_version "$version")
    version_dir="$UVM_VERSIONS_DIR/$version"
    
    # Check if version is installed
    if [ ! -d "$version_dir" ]; then
        echo "Error: $version is not installed" >&2
        exit 1
    fi
    
    # Check if it's the current version
    current_version=$(uvm_current_version)
    if [ "$version" = "$current_version" ]; then
        echo "Warning: $version is currently in use" >&2
        rm -f "$UVM_CURRENT_LINK"
    fi
    
    # Remove version directory
    rm -rf "$version_dir"
    
    # Remove from default if it was the default
    if [ -f "$UVM_DEFAULT_FILE" ] && [ "$(cat "$UVM_DEFAULT_FILE")" = "$version" ]; then
        rm -f "$UVM_DEFAULT_FILE"
    fi
    
    echo "Uninstalled $version"
}

uvm_run() {
    local version="$1"
    local version_dir vere_binary
    shift
    
    if [ -z "$version" ]; then
        echo "Error: Version required" >&2
        exit 1
    fi
    
    version=$(uvm_parse_version "$version")
    version_dir="$UVM_VERSIONS_DIR/$version"
    
    # Check if version is installed
    if [ ! -d "$version_dir" ]; then
        echo "Error: $version is not installed" >&2
        echo "Run 'uvm install $version' to install it" >&2
        exit 1
    fi
    
    # Find the urbit binary in the version directory
    local urbit_binary="$version_dir/urbit"
    
    if [ ! -f "$urbit_binary" ]; then
        echo "Error: urbit binary not found in $version" >&2
        exit 1
    fi
    
    # Execute urbit with the provided arguments
    exec "$urbit_binary" "$@"
}

uvm_exec() {
    local version="$1"
    local version_dir old_path
    shift
    
    if [ -z "$version" ]; then
        echo "Error: Version required" >&2
        exit 1
    fi
    
    version=$(uvm_parse_version "$version")
    version_dir="$UVM_VERSIONS_DIR/$version"
    
    # Check if version is installed
    if [ ! -d "$version_dir" ]; then
        echo "Error: $version is not installed" >&2
        echo "Run 'uvm install $version' to install it" >&2
        exit 1
    fi
    
    # Temporarily modify PATH and execute command
    old_path="$PATH"
    export PATH="$version_dir:$PATH"
    
    # Execute the command with the modified PATH
    "$@"
    local exit_code=$?
    
    # Restore original PATH
    export PATH="$old_path"
    
    return $exit_code
}

uvm_default() {
    local version="$1"
    local version_dir
    
    if [ -z "$version" ]; then
        if [ -f "$UVM_DEFAULT_FILE" ]; then
            cat "$UVM_DEFAULT_FILE"
        else
            echo "No default version set"
        fi
        return
    fi
    
    version=$(uvm_parse_version "$version")
    version_dir="$UVM_VERSIONS_DIR/$version"
    
    # Check if version is installed
    if [ ! -d "$version_dir" ]; then
        echo "Error: $version is not installed" >&2
        echo "Run 'uvm install $version' to install it" >&2
        exit 1
    fi
    
    # Save default version
    uvm_ensure_dirs
    echo "$version" > "$UVM_DEFAULT_FILE"
    
    echo "Default version set to $version"
}

uvm_which() {
    local version="$1"
    local version_dir vere_binary
    
    if [ -z "$version" ]; then
        echo "Error: Version required" >&2
        exit 1
    fi
    
    version=$(uvm_parse_version "$version")
    version_dir="$UVM_VERSIONS_DIR/$version"
    
    # Check if version is installed
    if [ ! -d "$version_dir" ]; then
        echo "Error: $version is not installed" >&2
        exit 1
    fi
    
    # Find the urbit binary
    local urbit_binary="$version_dir/urbit"
    
    if [ ! -f "$urbit_binary" ]; then
        echo "Error: urbit binary not found in $version" >&2
        exit 1
    fi
    
    echo "$urbit_binary"
}

uvm_alias() {
    local name="$1"
    local version="$2"
    local version_dir alias_file
    
    if [ -z "$name" ] || [ -z "$version" ]; then
        echo "Error: Both name and version required" >&2
        exit 1
    fi
    
    version=$(uvm_parse_version "$version")
    version_dir="$UVM_VERSIONS_DIR/$version"
    alias_file="$UVM_ALIASES_DIR/$name"
    
    # Check if version is installed
    if [ ! -d "$version_dir" ]; then
        echo "Error: $version is not installed" >&2
        echo "Run 'uvm install $version' to install it" >&2
        exit 1
    fi
    
    # Create alias
    uvm_ensure_dirs
    echo "$version" > "$alias_file"
    
    echo "Alias '$name' -> '$version' created"
}

uvm_unalias() {
    local name="$1"
    local alias_file
    
    if [ -z "$name" ]; then
        echo "Error: Alias name required" >&2
        exit 1
    fi
    
    alias_file="$UVM_ALIASES_DIR/$name"
    
    if [ ! -f "$alias_file" ]; then
        echo "Error: Alias '$name' does not exist" >&2
        exit 1
    fi
    
    rm "$alias_file"
    echo "Alias '$name' removed"
}

uvm_nuke() {
    echo "This will completely remove UVM and all its artifacts."
    echo "The following will be deleted:"
    echo "  - UVM directory: $UVM_HOME"
    echo "  - Shell configuration in your profile"
    echo "  - UVM wrapper in /usr/local/bin/uvm (if exists)"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        return 0
    fi
    
    echo "Removing UVM..."
    
    # Remove UVM directory
    if [ -d "$UVM_HOME" ]; then
        rm -rf "$UVM_HOME"
        echo "✓ Removed UVM directory: $UVM_HOME"
    fi
    
    # Remove wrapper from /usr/local/bin
    if [ -f "/usr/local/bin/uvm" ]; then
        if [ -w "/usr/local/bin" ]; then
            rm -f "/usr/local/bin/uvm"
            echo "✓ Removed UVM wrapper: /usr/local/bin/uvm"
        else
            sudo rm -f "/usr/local/bin/uvm" 2>/dev/null && echo "✓ Removed UVM wrapper: /usr/local/bin/uvm"
        fi
    fi
    
    # Remove shell configuration
    local shell_profiles=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.config/fish/config.fish")
    
    for profile in "${shell_profiles[@]}"; do
        if [ -f "$profile" ]; then
            # Create backup
            cp "$profile" "$profile.backup.uvm.$(date +%Y%m%d_%H%M%S)"
            
            # Remove UVM configuration
            awk '
            /^# UVM \(Urbit Version Manager\)/ { 
                in_uvm = 1
                next
            }
            in_uvm && /^[[:space:]]*$/ {
                next
            }
            in_uvm && /^[[:space:]]*#/ {
                next
            }
            in_uvm && /^[[:space:]]*export/ {
                next
            }
            in_uvm && /^[[:space:]]*\[/ {
                next
            }
            in_uvm && /^[[:space:]]*alias uvm=/ {
                in_uvm = 0
                next
            }
            in_uvm && /^# Explicitly add UVM current to PATH/ {
                next
            }
            in_uvm && /^if.*UVM_HOME.*current.*then/ {
                bracket_count = 1
                next
            }
            in_uvm && bracket_count > 0 && /fi/ {
                bracket_count--
                if (bracket_count == 0) {
                    in_uvm = 0
                }
                next
            }
            in_uvm && bracket_count > 0 {
                next
            }
            !in_uvm { print }
            ' "$profile" > "$profile.tmp"
            
            # Check if anything was actually removed
            if ! diff -q "$profile" "$profile.tmp" >/dev/null 2>&1; then
                mv "$profile.tmp" "$profile"
                echo "✓ Removed UVM configuration from: $profile"
            else
                rm -f "$profile.tmp"
            fi
        fi
    done
    
    echo ""
    echo "UVM has been completely uninstalled."
    echo "Backups of your shell profiles were created with .backup.uvm.* extensions."
    echo "Please restart your shell or source your profile to complete the removal."
    echo ""
    echo "Thank you for using UVM!"
}

uvm_read_uvmrc() {
    local uvmrc_file=".uvmrc"
    if [ -f "$uvmrc_file" ]; then
        cat "$uvmrc_file" | tr -d '\n\r'
    fi
}

# Main command dispatcher
main() {
    case "${1:-}" in
        ""|help) uvm_help ;;
        version) uvm_version ;;
        install) uvm_install "$2" ;;
        use) uvm_use "$2" ;;
        current) uvm_current ;;
        ls) uvm_ls ;;
        ls-remote) uvm_ls_remote ;;
        uninstall) uvm_uninstall "$2" ;;
        nuke) uvm_nuke ;;
        run) uvm_run "$2" "$@" ;;
        exec) uvm_exec "$2" "$@" ;;
        default) uvm_default "$2" ;;
        which) uvm_which "$2" ;;
        alias) uvm_alias "$2" "$3" ;;
        unalias) uvm_unalias "$2" ;;
        detect-platform) uvm_detect_platform ;;
        *)
            echo "Error: Unknown command '$1'" >&2
            echo "Run 'uvm help' for usage information" >&2
            exit 1
            ;;
    esac
}

# Shell integration functions
uvm_init() {
    # Only set up PATH to include current version
    if [ -L "$UVM_CURRENT_LINK" ] && [ -d "$UVM_CURRENT_LINK" ]; then
        # Check if already in PATH to avoid duplicates
        if ! echo "$PATH" | grep -q "$UVM_CURRENT_LINK"; then
            export PATH="$UVM_CURRENT_LINK:$PATH"
        fi
    fi
}

# Only run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Enable exit on error for command execution
    set -e
    main "$@"
else
    # Script is being sourced, initialize shell integration
    uvm_init
fi