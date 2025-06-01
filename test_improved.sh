#!/bin/bash
set -ueo pipefail

mkdir -p .local

PATH=$PWD:$PATH

echo "🧪 Testing Alpine Package Manager - Improved Version"
echo "=================================================="

# Test 1: Try Alpine GCC with improved environment
echo ""
echo "📋 Test 1: Installing Alpine GCC with improved environment..."

# Install Alpine packages
apk-local manager add gcc musl-dev linux-headers

echo ""
echo "📋 Checking Alpine GCC installation..."
apk-local env gcc --version

echo ""
echo "🔨 Test 2: Attempting compilation with Alpine GCC..."
# Try compilation with full Alpine environment
export LD_LIBRARY_PATH=".local/alpine/lib:.local/alpine/usr/lib:${LD_LIBRARY_PATH:-}"
export PATH=".local/alpine/usr/bin:.local/alpine/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0:$PATH"

if .local/alpine/lib/ld-musl-x86_64.so.1 .local/alpine/usr/bin/gcc tests/test_compile.c -o test_compile_alpine 2>/dev/null; then
    echo "✅ Alpine GCC compilation successful!"
    echo "🚀 Running Alpine-compiled program..."
    .local/alpine/lib/ld-musl-x86_64.so.1 ./test_compile_alpine
    echo "✅ Alpine GCC test passed!"
    ALPINE_SUCCESS=true
else
    echo "❌ Alpine GCC compilation failed (expected due to musl/glibc incompatibility)"
    ALPINE_SUCCESS=false
fi

echo ""
echo "🔨 Test 3: Fallback to system GCC..."
if command -v gcc >/dev/null 2>&1; then
    echo "📋 System GCC version:"
    gcc --version | head -1
    
    echo "🔨 Compiling with system GCC..."
    gcc tests/test_compile.c -o test_compile_system
    
    echo "🔍 Checking system binary dependencies..."
    if command -v ldd >/dev/null 2>&1; then
        ldd test_compile_system || echo "Note: ldd may not show dependencies for static binaries"
    fi
    
    echo "🚀 Running system-compiled program..."
    ./test_compile_system
    echo "✅ System GCC test passed!"
    SYSTEM_SUCCESS=true
else
    echo "❌ System GCC not available"
    SYSTEM_SUCCESS=false
fi

echo ""
echo "🔨 Test 4: Testing Alpine static compilation..."
if [ "$ALPINE_SUCCESS" = false ]; then
    echo "🔧 Trying Alpine GCC with static linking..."
    if .local/alpine/lib/ld-musl-x86_64.so.1 .local/alpine/usr/bin/gcc -static tests/test_compile.c -o test_compile_static 2>/dev/null; then
        echo "✅ Alpine static compilation successful!"
        echo "🚀 Running statically-compiled program..."
        ./test_compile_static
        echo "✅ Alpine static compilation test passed!"
        STATIC_SUCCESS=true
    else
        echo "❌ Alpine static compilation also failed"
        STATIC_SUCCESS=false
    fi
else
    STATIC_SUCCESS=true  # Skip if dynamic worked
fi

echo ""
echo "=================================================="
echo "📊 Test Results Summary:"
echo "=================================================="

if [ "$ALPINE_SUCCESS" = true ]; then
    echo "✅ Alpine GCC (dynamic): SUCCESS"
elif [ "$STATIC_SUCCESS" = true ]; then
    echo "✅ Alpine GCC (static): SUCCESS"  
else
    echo "❌ Alpine GCC: FAILED"
fi

if [ "$SYSTEM_SUCCESS" = true ]; then
    echo "✅ System GCC: SUCCESS"
else
    echo "❌ System GCC: FAILED"
fi

echo ""
if [ "$ALPINE_SUCCESS" = true ] || [ "$STATIC_SUCCESS" = true ]; then
    echo "🎉 Alpine package manager is functional!"
    echo "💡 Recommendation: Use Alpine packages for development"
elif [ "$SYSTEM_SUCCESS" = true ]; then
    echo "⚠️  Alpine GCC has compatibility issues, but system GCC works"
    echo "💡 Recommendation: Use system packages or improve Alpine environment"
else
    echo "❌ Both Alpine and system GCC failed"
    echo "💡 Recommendation: Check environment setup"
fi

echo ""
echo "🔧 Suggested improvements for Alpine compatibility:"
echo "   1. Use containerized environment (Docker/Podman)"
echo "   2. Set up proper chroot environment for Alpine"
echo "   3. Use Alpine static binaries when possible"
echo "   4. Consider using musl-based host system"