# Alpine Environment - Docker-free Alpine Linux with Channel Switching

**Run Alpine Linux GCC and tools natively on Ubuntu/glibc systems** - A lightweight Alpine environment using bubblewrap that supports multiple Alpine channels without Docker.

## 🚀 Quick Start

```bash
# Set up Alpine environment (defaults to v3.19)
./alpine-env.sh run gcc --version

# Or choose a specific Alpine channel
./alpine-env.sh setup edge        # Latest bleeding-edge
./alpine-env.sh setup v3.22       # Alpine 3.22 stable
./alpine-env.sh setup v3.19       # Alpine 3.19 stable

# Compile and run programs
./alpine-env.sh run gcc hello.c -o hello
./alpine-env.sh run ./hello

# Install additional packages
./alpine-env.sh run apk add nodejs npm python3
./alpine-env.sh run node --version
```

## 🏔️ Available Alpine Channels

- **v3.19** - Alpine 3.19 stable (GCC 13.2.1)
- **v3.20** - Alpine 3.20 stable  
- **v3.21** - Alpine 3.21 stable
- **v3.22** - Alpine 3.22 stable (GCC 14.2.0) - **Current**
- **edge** - Latest bleeding-edge packages (GCC 14.3.0)
- **latest-stable** - Latest stable release (currently 3.22)

## 📋 What You Get

- ✅ **Native Alpine GCC** - Compile with musl libc on glibc systems
- ✅ **Multiple Alpine versions** - Switch between stable and edge channels
- ✅ **No Docker required** - Uses bubblewrap for lightweight containerization
- ✅ **No sudo required** - Installs to user space (`~/.local/alpine-env`)
- ✅ **Complete development environment** - GCC, G++, make, cmake, musl-dev included
- ✅ **APK package management** - Install any Alpine package
- ✅ **Single script** - Everything in one executable

## 🛠️ Commands

### Setup Commands
```bash
./alpine-env.sh setup <channel>    # Set up specific Alpine channel
./alpine-env.sh setup edge         # Set up Alpine edge (latest)
./alpine-env.sh setup v3.22        # Set up Alpine 3.22 stable
./alpine-env.sh setup v3.19        # Set up Alpine 3.19 stable
```

### Run Commands
```bash
./alpine-env.sh run <command>      # Run any command in Alpine environment
./alpine-env.sh run gcc --version  # Check GCC version
./alpine-env.sh run apk add nodejs # Install packages
./alpine-env.sh run /bin/sh        # Get Alpine shell
```

## 📖 Usage Examples

### Development Workflow
```bash
# Set up Alpine edge for latest tools
./alpine-env.sh setup edge

# Install development packages
./alpine-env.sh run apk add git nodejs npm python3 curl

# Compile C programs with Alpine GCC
./alpine-env.sh run gcc -static myapp.c -o myapp

# Run the compiled binary
./alpine-env.sh run ./myapp
```

### Cross-Channel Testing
```bash
# Test with Alpine edge (GCC 14.3.0)
./alpine-env.sh setup edge
./alpine-env.sh run gcc --version
./alpine-env.sh run gcc test.c -o test_edge

# Test with Alpine 3.22 stable (GCC 14.2.0)  
./alpine-env.sh setup v3.22
./alpine-env.sh run gcc --version
./alpine-env.sh run gcc test.c -o test_stable

# Compare results
./alpine-env.sh run ./test_edge
./alpine-env.sh run ./test_stable
```

### Package Management
```bash
# Search for packages
./alpine-env.sh run apk search nodejs

# Install packages
./alpine-env.sh run apk add nodejs npm yarn

# Check installed packages
./alpine-env.sh run apk list --installed

# Update package index
./alpine-env.sh run apk update
```

### Interactive Shell
```bash
# Get an Alpine shell
./alpine-env.sh run /bin/sh

# Inside the shell, you have full Alpine environment:
# apk add vim
# gcc --version
# cat /etc/alpine-release
# exit
```

## 🔧 Technical Details

### How It Works
- **Bubblewrap containerization** - Lightweight namespace isolation
- **Alpine minirootfs** - Downloads minimal Alpine filesystem
- **Automatic toolchain setup** - Installs GCC, G++, musl-dev, make, cmake
- **Volume mounting** - Your current directory is available as `/tmp/workspace`
- **Network access** - Full internet connectivity for APK operations

### System Requirements
- **Linux system** (Ubuntu, Debian, etc.)
- **bubblewrap** package installed:
  ```bash
  # Ubuntu/Debian
  sudo apt install bubblewrap
  
  # Fedora/RHEL
  sudo dnf install bubblewrap
  
  # Arch Linux
  sudo pacman -S bubblewrap
  ```

### File Structure
```
~/.local/alpine-env/          # Alpine environment root
├── bin/                      # Alpine binaries
├── usr/                      # Alpine user programs
├── etc/                      # Alpine configuration
└── var/                      # Alpine variable data
```

## 🆚 Why Alpine Environment?

### vs Docker
- ✅ **Faster startup** - No container overhead
- ✅ **Native performance** - Direct system calls
- ✅ **Simpler setup** - No Docker daemon required
- ✅ **Better integration** - Direct file system access

### vs Native GCC
- ✅ **musl libc** - Smaller, more secure binaries
- ✅ **Static linking** - Self-contained executables
- ✅ **Reproducible builds** - Consistent Alpine environment
- ✅ **Multiple versions** - Switch between Alpine channels

### vs Virtual Machines
- ✅ **Lightweight** - Minimal resource usage
- ✅ **Fast** - Near-native performance
- ✅ **Integrated** - Shares host filesystem
- ✅ **Simple** - Single script operation

## 🧪 Testing

Run the comprehensive test suite:
```bash
./test.sh
```

This tests:
- Multiple Alpine channels (v3.19, edge, v3.22)
- GCC compilation and execution
- APK package management
- Shell access
- Binary compatibility

## 🆘 Troubleshooting

### Bubblewrap Not Found
```bash
# Install bubblewrap
sudo apt install bubblewrap  # Ubuntu/Debian
sudo dnf install bubblewrap  # Fedora/RHEL
sudo pacman -S bubblewrap    # Arch Linux
```

### Container Environment Issues
If you see "bubblewrap cannot create namespaces" in Docker/containers:

**This is expected behavior** - most containers disable user namespaces for security.

**Solutions:**
1. **Run on host system** (recommended):
   ```bash
   # Copy script to host and run there
   docker cp container:/path/to/alpine-env.sh .
   ./alpine-env.sh run gcc --version
   ```

2. **Privileged container** (not recommended):
   ```bash
   docker run --privileged ...
   ```

3. **Enable user namespaces**:
   ```bash
   docker run --cap-add=SYS_ADMIN --security-opt seccomp=unconfined ...
   ```

### Permission Errors
The script automatically handles permission errors in containerized environments. The "ERROR: X errors updating directory permissions" messages are normal and expected.

### Kernel User Namespace Issues
On some systems, user namespaces may be disabled:
```bash
# Enable user namespaces
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/00-local-userns.conf
sudo sysctl --system
```

### Network Issues
Ensure your system has internet connectivity for downloading Alpine packages and repositories.

## 🎯 Use Cases

- **Cross-compilation** - Build musl binaries on glibc systems
- **Alpine development** - Test packages before Alpine deployment
- **Static binaries** - Create self-contained executables
- **Security research** - Analyze musl vs glibc behavior
- **CI/CD pipelines** - Consistent Alpine builds without Docker
- **Educational** - Learn Alpine Linux and musl libc

## 🎉 Success!

You now have a complete Alpine Linux development environment that runs natively on your glibc system, with the ability to switch between different Alpine channels for testing and development! 🏔️

**No Docker, no VMs, just pure Alpine goodness!**