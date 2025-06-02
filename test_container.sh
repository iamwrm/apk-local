#!/bin/bash
set -ueo pipefail

echo "🐳 Container Environment Test"
echo "============================"

# Check if we're in a container
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "✅ Detected container environment"
else
    echo "ℹ️  Not detected as container environment"
fi

echo ""
echo "🔍 Testing bubblewrap availability..."

if ! command -v bwrap >/dev/null 2>&1; then
    echo "❌ bubblewrap not installed"
    echo "📦 Installing bubblewrap..."
    if command -v apt >/dev/null 2>&1; then
        apt-get update && apt-get install -y bubblewrap
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y bubblewrap
    elif command -v pacman >/dev/null 2>&1; then
        pacman -S --noconfirm bubblewrap
    else
        echo "❌ Cannot install bubblewrap automatically"
        exit 1
    fi
fi

echo "✅ bubblewrap is installed"

echo ""
echo "🧪 Testing bubblewrap namespace creation..."

if bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --unshare-all --die-with-parent true >/dev/null 2>&1; then
    echo "✅ bubblewrap can create namespaces"
    echo ""
    echo "🏔️ Running Alpine environment test..."
    ./alpine-env.sh run echo "Alpine environment works in container!"
else
    echo "❌ bubblewrap cannot create namespaces"
    echo ""
    echo "🐳 Container Environment Limitations"
    echo "===================================="
    echo ""
    echo "This is expected in most container environments where user namespaces"
    echo "are disabled for security reasons."
    echo ""
    echo "🔧 Solutions:"
    echo ""
    echo "1. 🏠 Run on Host System (Recommended)"
    echo "   Copy alpine-env.sh to your host system and run there:"
    echo "   docker cp container:/path/to/alpine-env.sh ."
    echo "   ./alpine-env.sh run gcc --version"
    echo ""
    echo "2. 🔓 Privileged Container (Not Recommended)"
    echo "   docker run --privileged ..."
    echo ""
    echo "3. 🔧 Enable User Namespaces"
    echo "   Add to docker run: --security-opt apparmor:unconfined"
    echo "   Or use: --cap-add=SYS_ADMIN --security-opt seccomp=unconfined"
    echo ""
    echo "4. 🐋 Docker Desktop Alternative"
    echo "   Use Docker Desktop with enhanced container support"
    echo ""
    echo "💡 For CI/CD, consider using alpine-env.sh on the runner host"
    echo "   rather than inside containers."
fi

echo ""
echo "📋 Environment Information:"
echo "=========================="
echo "Kernel: $(uname -r)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "Container: $([ -f /.dockerenv ] && echo "Docker" || echo "Unknown/None")"
echo "User: $(whoami) (UID: $(id -u))"
echo "Namespaces: $(ls /proc/self/ns/ | wc -l) available"
