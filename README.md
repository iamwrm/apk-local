# APK Local - Unified Alpine Package Manager

**One script to rule them all** - A unified Alpine package manager for container environments that doesn't require sudo.

## 🚀 Quick Start

```bash
# Install packages
./apk-local manager add git vim htop curl

# Run commands with Alpine PATH
./apk-local env git status

# Load environment variables
source <(./apk-local export)
git --version  # Now uses Alpine git
```

## 📋 What You Get

- ✅ **Complete package management** - Install, search, update Alpine packages
- ✅ **Container-friendly** - Works in LXC/Docker without nested containers  
- ✅ **No sudo required** - Installs to user space (`$PWD/.local/alpine`)
- ✅ **Temporary command execution** - Run binaries with Alpine PATH
- ✅ **Environment export** - Source environment variables for persistent access
- ✅ **Single script** - Everything unified in one executable

## 🛠️ Commands

### Package Management
```bash
./apk-local manager add <packages>     # Install packages
./apk-local manager search <term>      # Search packages  
./apk-local manager update             # Update package index
./apk-local manager list               # List installed packages
./apk-local manager del <package>      # Remove package
```

### Environment Management
```bash
./apk-local env <binary> [args...]     # Run binary with Alpine PATH
./apk-local export                     # Export environment variables
source <(./apk-local export)           # Load environment
```

## 📖 Usage Examples

### Install Development Tools
```bash
./apk-local manager add git nodejs npm python3 curl wget vim
```

### Run Commands Temporarily
```bash
./apk-local env git clone https://github.com/user/repo.git
./apk-local env node --version
./apk-local env python3 script.py
```

### Persistent Environment
```bash
# Load Alpine environment
source <(./apk-local export)

# Now all Alpine packages are in PATH
git --version     # Alpine git
node --version    # Alpine node
python3 --version # Alpine python3
```

### Project-Specific Setup
```bash
# Different directories can have different Alpine environments
cd ~/project1
./apk-local manager add nodejs npm
source <(./apk-local export)

cd ~/project2
./apk-local manager add python3 pip
source <(./apk-local export)
```

## 📁 File Structure

```
your-project/
├── .local/alpine/usr/bin/    # Installed Alpine binaries
├── apk-local                 # Unified script ⭐
└── apk.static               # Alpine package manager binary
```

## 🎯 Key Features

### Unified Interface
- **One script** handles everything (package management, environment, execution)
- **Consistent syntax** across all operations
- **No multiple files** to manage

### Smart Environment Management  
- **Automatic detection** of Alpine vs system binaries
- **Temporary execution** without changing global environment
- **Easy environment export** for persistent access
- **Helpful aliases** when sourcing environment

### Container Optimized
- **No sudo required** - everything in user space
- **Container-friendly** - works in LXC, Docker, etc.
- **Permission error handling** - graceful degradation in restricted environments
- **Isolated installations** - per-directory Alpine environments
- **Smart compatibility** - uses Alpine's musl dynamic linker to run Alpine binaries on glibc systems

## 🆘 Getting Help

```bash
./apk-local                    # Show main help
./apk-local manager           # Show package manager help  
./apk-local env               # Show environment help
```

## 📚 Documentation

- **[QUICK_START.md](QUICK_START.md)** - Detailed usage guide

## 🎉 Success!

You now have a complete, unified Alpine package management system that works without sudo in any container environment. Everything you need in one script! 🏔️