# Urbit Version Manager

UVM is a utility script for managing different releases of the Urbit runtime ([Vere](https://github.com/urbit/vere/releases)).

## Features

- **Version Management**: Install, switch between, and manage multiple runtime versions
- **Platform Support**: Supports Linux and macOS with automatic platform detection
- **Shell Integration**: Automatic PATH management and version switching
- **Project Support**: `.uvmrc` file support for project-specific versions
- **Aliases**: Create custom aliases for version management
- **GitHub Integration**: Fetches releases directly from urbit/vere repository

## Installation

### Quick Install (Recommended)

```bash
curl -o- https://raw.githubusercontent.com/labwet/uvm/main/install.sh | bash
```

Or with wget:

```bash
wget -qO- https://raw.githubusercontent.com/labwet/uvm/main/install.sh | bash
```

### Manual Install

1. Clone or download the repository
2. Run the install script:

```bash
./install.sh
```

3. Restart your shell or run:

```bash
source ~/.bashrc  # or ~/.zshrc
```

## Usage

### Basic Commands

```bash
# Show help
uvm

# Install a specific version
uvm install vere-v3.4

# List available remote versions
uvm ls-remote

# List installed versions
uvm ls

# Switch to a version
uvm use vere-v3.4

# Show current version
uvm current

# Run urbit with a specific version
uvm run vere-v3.4 --help

# Execute command with specific version in PATH
uvm exec vere-v3.4 which urbit

# Set default version
uvm default vere-v3.4

# Show path to version
uvm which vere-v3.4

# Uninstall a version
uvm uninstall vere-v3.4

# Completely remove UVM (nuclear option)
uvm nuke
```

### Version Aliases

```bash
# Create an alias
uvm alias latest vere-v3.4

# Use alias
uvm use latest

# Remove alias
uvm unalias latest
```

### Project-Specific Versions

Create a `.uvmrc` file in your project directory:

```bash
echo "vere-v3.4" > .uvmrc
```

Then use:

```bash
# Install version from .uvmrc
uvm install

# Switch to version from .uvmrc
uvm use
```

UVM will automatically switch to the correct version when you `cd` into directories with `.uvmrc` files.

### Version Formats

UVM accepts various version formats:

- `vere-v3.4` (full format)
- `v3.4` (short format)
- `3.4` (minimal format)
- `latest` (if aliased)

## Configuration

### Environment Variables

- `UVM_HOME`: UVM installation directory (default: `~/.uvm`)

### Directory Structure

```
~/.uvm/
├── uvm.sh              # Main script
├── versions/           # Installed versions
│   ├── vere-v3.4/
│   └── vere-v3.3/
├── aliases/            # Version aliases
├── current -> versions/vere-v3.4/  # Current version symlink
└── default             # Default version file
```

## Shell Integration

UVM automatically integrates with your shell:

- **Bash**: Uses `cd` hook for auto-switching
- **Zsh**: Uses `chpwd` hook for auto-switching
- **Fish**: Basic integration (manual switching)

## Platform Support

UVM supports:

- **Linux**: x86_64, aarch64
- **macOS**: x86_64 (Intel), aarch64 (Apple Silicon)

## Examples

### Install and use latest version

```bash
# List available versions
uvm ls-remote

# Install latest version
uvm install vere-v3.4

# Switch to it
uvm use vere-v3.4

# Verify it's available in PATH
which urbit
# Should show: /Users/your-username/.uvm/current/urbit

# Run urbit directly (global command)
urbit -R
# Should show version info

# Note: You may need to restart your terminal or run:
# source ~/.zshrc (for zsh) or source ~/.bashrc (for bash)

# Set as default
uvm default vere-v3.4
```

### Project workflow

```bash
# Create project
mkdir my-urbit-project
cd my-urbit-project

# Specify version for project
echo "vere-v3.4" > .uvmrc

# Install required version
uvm install

# Version is automatically active in this directory
uvm current  # Shows: vere-v3.4
```

### Run specific version

```bash
# Run urbit v3.4 without switching
uvm run vere-v3.4 --help

# Execute command with v3.4 in PATH
uvm exec vere-v3.4 which urbit
```

## Uninstalling UVM

To completely remove UVM and all its artifacts:

```bash
uvm nuke
```

This will:
- Remove the `~/.uvm` directory and all installed versions
- Remove UVM configuration from your shell profiles (`.bashrc`, `.zshrc`, etc.)
- Remove the UVM wrapper from `/usr/local/bin/uvm` (if exists)
- Create backups of your shell profiles before modification

## Troubleshooting

### Common Issues

1. **Permission Denied**: Make sure uvm.sh is executable: `chmod +x ~/.uvm/uvm.sh`
2. **Command Not Found**: Restart your shell or source your profile
3. **Download Fails**: Check internet connection and GitHub API rate limits
4. **Version Not Found**: Verify version exists with `uvm ls-remote`
5. **`which urbit` returns nothing**: Make sure you've run `uvm use <version>` and restart your shell
6. **`urbit` command not found**: Verify your shell integration is working:
   ```bash
   echo $UVM_HOME  # Should show ~/.uvm
   ls -la ~/.uvm/current  # Should show symlink to active version
   echo $PATH | grep uvm  # Should show ~/.uvm/current in PATH
   ```
   
   If the PATH doesn't include UVM:
   - Restart your terminal completely
   - Or run: `source ~/.zshrc` (zsh) or `source ~/.bashrc` (bash)
   - Verify you've run `uvm use <version>` to set a current version

### Debug Mode

Run with debug output:

```bash
bash -x ~/.uvm/uvm.sh install vere-v3.4
```

### Clean Install

Remove UVM completely:

```bash
rm -rf ~/.uvm
# Remove lines from ~/.bashrc or ~/.zshrc
```

## Development

### Testing

Run the test suite:

```bash
./test_uvm.sh
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Inspired by [nvm](https://github.com/nvm-sh/nvm)
- Uses the [urbit/vere](https://github.com/urbit/vere) release API
