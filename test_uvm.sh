#!/bin/bash

# Test script for UVM functionality

set -e

UVM_SCRIPT="$(pwd)/uvm.sh"
TEST_DIR="/tmp/uvm_test"
export UVM_HOME="$TEST_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[TEST]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

error() {
    echo -e "${RED}[TEST]${NC} $1"
}

# Clean up function
cleanup() {
    rm -rf "$TEST_DIR"
    log "Cleaned up test directory"
}

# Set up test environment
setup() {
    log "Setting up test environment..."
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR"
    log "Created test directory: $TEST_DIR"
}

# Test basic commands
test_basic_commands() {
    log "Testing basic commands..."
    
    # Test version
    local version_output
    version_output=$($UVM_SCRIPT version)
    if [ "$version_output" = "1.0.0" ]; then
        log "✓ Version command works"
    else
        error "✗ Version command failed: $version_output"
        return 1
    fi
    
    # Test current (should be empty)
    local current_output
    current_output=$($UVM_SCRIPT current)
    if [ "$current_output" = "No version currently in use" ]; then
        log "✓ Current command works"
    else
        error "✗ Current command failed: $current_output"
        return 1
    fi
    
    # Test ls (should be empty)
    local ls_output
    ls_output=$($UVM_SCRIPT ls)
    if [ "$ls_output" = "No versions installed" ]; then
        log "✓ List command works"
    else
        error "✗ List command failed: $ls_output"
        return 1
    fi
    
    # Test platform detection
    local platform_output
    platform_output=$($UVM_SCRIPT detect-platform)
    if echo "$platform_output" | grep -q "^macos-"; then
        log "✓ Platform detection works: $platform_output"
    else
        error "✗ Platform detection failed: $platform_output"
        return 1
    fi
}

# Test remote listing
test_remote_listing() {
    log "Testing remote listing..."
    
    # Test ls-remote (requires internet)
    local remote_output
    if remote_output=$($UVM_SCRIPT ls-remote 2>&1); then
        if echo "$remote_output" | grep -q "vere-v"; then
            log "✓ Remote listing works"
        else
            error "✗ Remote listing failed: $remote_output"
            return 1
        fi
    else
        warn "⚠ Remote listing failed (network issue?): $remote_output"
    fi
}

# Test .uvmrc functionality
test_uvmrc() {
    log "Testing .uvmrc functionality..."
    
    # Create a .uvmrc file
    echo "vere-v3.4" > "$TEST_DIR/.uvmrc"
    
    # Test reading .uvmrc
    local uvmrc_content
    uvmrc_content=$(cd "$TEST_DIR" && source "$UVM_SCRIPT" && uvm_read_uvmrc 2>/dev/null || echo "")
    
    if [ "$uvmrc_content" = "vere-v3.4" ]; then
        log "✓ .uvmrc reading works"
    else
        warn "⚠ .uvmrc reading not working as expected (got: '$uvmrc_content')"
    fi
    
    # Clean up
    rm -f "$TEST_DIR/.uvmrc"
}

# Test installation (mock test - don't actually install)
test_installation_validation() {
    log "Testing installation validation..."
    
    # Test with invalid version
    if $UVM_SCRIPT install "nonexistent-version" 2>/dev/null; then
        error "✗ Installation should fail for invalid version"
        return 1
    else
        log "✓ Installation properly rejects invalid versions"
    fi
    
    # Test use without installation
    if $UVM_SCRIPT use "vere-v3.4" 2>/dev/null; then
        error "✗ Use should fail for non-installed version"
        return 1
    else
        log "✓ Use properly rejects non-installed versions"
    fi
}

# Test alias functionality
test_aliases() {
    log "Testing alias functionality..."
    
    # Test alias without installation (should fail)
    if $UVM_SCRIPT alias "latest" "vere-v3.4" 2>/dev/null; then
        error "✗ Alias should fail for non-installed version"
        return 1
    else
        log "✓ Alias properly rejects non-installed versions"
    fi
}

# Main test function
main() {
    log "Starting UVM tests..."
    
    # Trap to ensure cleanup
    trap cleanup EXIT
    
    setup
    test_basic_commands
    test_remote_listing
    test_uvmrc
    test_installation_validation
    test_aliases
    
    log "All tests completed successfully!"
}

# Run tests
main "$@"