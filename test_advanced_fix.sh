#!/bin/bash
set -euo pipefail

echo "🔬 Advanced Alpine GCC Fix - Multiple Approaches"
echo "================================================="

mkdir -p .local
PATH=$PWD:$PATH

# Ensure Alpine packages are installed
echo "📦 Ensuring Alpine GCC is installed..."
apk-local manager add gcc musl-dev >/dev/null 2>&1 || true

ALPINE_ROOT="$PWD/.local/alpine"
ALPINE_LD="$ALPINE_ROOT/lib/ld-musl-x86_64.so.1"
ALPINE_GCC="$ALPINE_ROOT/usr/bin/gcc"

echo ""
echo "🔧 Approach 1: Direct Binary Replacement with Script Injection"
echo "==============================================================="

# Create a custom cc1 wrapper that uses the Alpine dynamic linker
CC1_DIR="$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0"
CC1_ORIG="$CC1_DIR/cc1.original"
CC1_PATH="$CC1_DIR/cc1"

if [ ! -f "$CC1_ORIG" ]; then
    echo "🔧 Creating enhanced cc1 wrapper..."
    cp "$CC1_PATH" "$CC1_ORIG"
    
    cat > "$CC1_PATH" << 'EOF'
#!/bin/bash
# Enhanced cc1 wrapper that ensures Alpine dynamic linker is used

# Get the directory of this script
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ALPINE_ROOT="$(dirname "$(dirname "$(dirname "$(dirname "$DIR")")")")"
ALPINE_LD="$ALPINE_ROOT/lib/ld-musl-x86_64.so.1"
CC1_ORIG="$DIR/cc1.original"

# Set up Alpine environment
export LD_LIBRARY_PATH="$ALPINE_ROOT/lib:$ALPINE_ROOT/usr/lib:${LD_LIBRARY_PATH:-}"

# Execute original cc1 with Alpine dynamic linker
exec "$ALPINE_LD" "$CC1_ORIG" "$@"
EOF
    
    chmod +x "$CC1_PATH"
    echo "✅ Enhanced cc1 wrapper created"
fi

echo ""
echo "🧪 Testing Approach 1..."
if .local/alpine/lib/ld-musl-x86_64.so.1 .local/alpine/usr/bin/gcc tests/test_compile.c -o test_approach1 2>/dev/null; then
    echo "✅ Approach 1 SUCCESS: Alpine GCC compilation worked!"
    echo "🚀 Running the compiled program..."
    .local/alpine/lib/ld-musl-x86_64.so.1 ./test_approach1
    APPROACH1_SUCCESS=true
else
    echo "❌ Approach 1 failed"
    APPROACH1_SUCCESS=false
fi

echo ""
echo "🔧 Approach 2: Environment Variable Method with Subprocess Control"
echo "=================================================================="

# Try using more environment variables to control subprocess execution
export GCCDIR="$PWD/$ALPINE_ROOT/usr/bin"
export GCC_EXEC_PREFIX="$PWD/$ALPINE_ROOT/usr/libexec/gcc/"
export LIBRARY_PATH="$PWD/$ALPINE_ROOT/lib:$PWD/$ALPINE_ROOT/usr/lib"
export LD_LIBRARY_PATH="$PWD/$ALPINE_ROOT/lib:$PWD/$ALPINE_ROOT/usr/lib:${LD_LIBRARY_PATH:-}"

echo "🧪 Testing Approach 2..."
if env -i \
    PATH="$PWD/$ALPINE_ROOT/usr/bin:$PWD/$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0:$PATH" \
    LD_LIBRARY_PATH="$PWD/$ALPINE_ROOT/lib:$PWD/$ALPINE_ROOT/usr/lib" \
    GCC_EXEC_PREFIX="$PWD/$ALPINE_ROOT/usr/libexec/gcc/" \
    "$ALPINE_LD" "$ALPINE_GCC" tests/test_compile.c -o test_approach2 2>/dev/null; then
    echo "✅ Approach 2 SUCCESS: Environment control worked!"
    echo "🚀 Running the compiled program..."
    "$ALPINE_LD" ./test_approach2
    APPROACH2_SUCCESS=true
else
    echo "❌ Approach 2 failed"  
    APPROACH2_SUCCESS=false
fi

echo ""
echo "🔧 Approach 3: Namespace/Chroot Simulation"
echo "==========================================="

# Create a temporary directory that simulates a chroot environment
TEMP_ROOT="/tmp/alpine_chroot_$$"
mkdir -p "$TEMP_ROOT"

# Create symbolic links to simulate a proper Alpine environment
mkdir -p "$TEMP_ROOT/lib" "$TEMP_ROOT/usr/bin" "$TEMP_ROOT/usr/libexec"
ln -sf "$PWD/$ALPINE_ROOT/lib/"* "$TEMP_ROOT/lib/" 2>/dev/null || true
ln -sf "$PWD/$ALPINE_ROOT/usr/bin/"* "$TEMP_ROOT/usr/bin/" 2>/dev/null || true  
ln -sf "$PWD/$ALPINE_ROOT/usr/libexec/"* "$TEMP_ROOT/usr/libexec/" 2>/dev/null || true

echo "🧪 Testing Approach 3..."
# This approach simulates what would happen in a proper chroot
if env -i \
    PATH="/usr/bin:/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0" \
    LD_LIBRARY_PATH="/lib" \
    PWD="$PWD" \
    "$TEMP_ROOT/lib/ld-musl-x86_64.so.1" "$TEMP_ROOT/usr/bin/gcc" tests/test_compile.c -o test_approach3 2>/dev/null; then
    echo "✅ Approach 3 SUCCESS: Namespace simulation worked!"
    echo "🚀 Running the compiled program..."
    "$TEMP_ROOT/lib/ld-musl-x86_64.so.1" ./test_approach3
    APPROACH3_SUCCESS=true
else
    echo "❌ Approach 3 failed"
    APPROACH3_SUCCESS=false
fi

# Cleanup
rm -rf "$TEMP_ROOT"

echo ""
echo "================================================="
echo "📊 Advanced Test Results:"
echo "================================================="

if [ "$APPROACH1_SUCCESS" = true ]; then
    echo "✅ Approach 1 (Binary Wrapper): SUCCESS"
elif [ "$APPROACH2_SUCCESS" = true ]; then
    echo "✅ Approach 2 (Environment Control): SUCCESS"
elif [ "$APPROACH3_SUCCESS" = true ]; then
    echo "✅ Approach 3 (Namespace Simulation): SUCCESS"
else
    echo "❌ All advanced approaches failed"
    echo ""
    echo "🔍 Let's diagnose the exact issue..."
    echo "Running gcc with maximum verbosity:"
    "$ALPINE_LD" "$ALPINE_GCC" -v -Q tests/test_compile.c -o test_debug 2>&1 | head -20
fi

echo ""
echo "💡 Summary:"
if [ "$APPROACH1_SUCCESS" = true ] || [ "$APPROACH2_SUCCESS" = true ] || [ "$APPROACH3_SUCCESS" = true ]; then
    echo "🎉 SUCCESS: Found a working solution for Alpine GCC!"
    echo "The key was ensuring cc1 gets the proper Alpine environment."
else
    echo "⚠️  Advanced approaches also failed. This suggests a fundamental"
    echo "   compatibility issue that may require container isolation."
fi