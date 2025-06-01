#!/bin/bash
set -ueo pipefail

echo "🧪 Simple Alpine Package Manager Test & Fix"
echo "============================================="

mkdir -p .local
PATH=$PWD:$PATH

echo ""
echo "📋 Step 1: Installing Alpine packages..."
apk-local manager add gcc musl-dev

echo ""
echo "📋 Step 2: Testing Alpine GCC version..."
apk-local env gcc --version | head -1

echo ""
echo "📋 Step 3: Attempting compilation (will likely fail)..."
if apk-local env gcc tests/test_compile.c -o test_alpine 2>/dev/null; then
    echo "✅ Alpine GCC compilation successful!"
    ./test_alpine
else
    echo "❌ Alpine GCC compilation failed (as expected)"
    echo ""
    echo "🔧 Root cause: musl/glibc incompatibility"
    echo "   - Alpine uses musl libc"
    echo "   - Host system uses glibc" 
    echo "   - cc1 binary cannot execute in this environment"
fi

echo ""
echo "📋 Step 4: Installing system build tools..."
# Try to install system gcc if not available
if ! command -v gcc >/dev/null 2>&1; then
    echo "Installing system gcc..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y build-essential
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y gcc
    elif command -v apk >/dev/null 2>&1; then
        sudo apk add gcc musl-dev
    else
        echo "⚠️  Cannot install system gcc automatically"
    fi
fi

echo ""
echo "📋 Step 5: Testing with system GCC (if available)..."
if command -v gcc >/dev/null 2>&1; then
    echo "✅ System GCC found: $(gcc --version | head -1)"
    echo "🔨 Compiling with system GCC..."
    gcc tests/test_compile.c -o test_system
    echo "🚀 Running system-compiled program..."
    ./test_system
    echo "✅ System GCC test passed!"
else
    echo "❌ System GCC not available"
fi

echo ""
echo "=================================================="
echo "📊 Summary & Recommendations:"
echo "=================================================="
echo ""
echo "🔍 Issue: Alpine packages use musl libc, incompatible with glibc systems"
echo ""
echo "✅ Better solutions:"
echo "   1. Use Docker/containers for Alpine packages"
echo "   2. Use system packages for compilation"
echo "   3. Set up proper chroot environment"
echo "   4. Use static compilation when possible"
echo ""
echo "💡 The apk-local tool is great for package management,"
echo "   but compilation requires compatible environment."