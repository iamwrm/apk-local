#!/bin/bash
set -euo pipefail

echo "🎯 PATH-Based Alpine GCC Solution"
echo "=================================="

mkdir -p .local
PATH=$PWD:$PATH

# Ensure Alpine packages are installed
echo "📦 Ensuring Alpine GCC is installed..."
apk-local manager add gcc musl-dev >/dev/null 2>&1 || true

ALPINE_ROOT="$PWD/.local/alpine"
ALPINE_LD="$ALPINE_ROOT/lib/ld-musl-x86_64.so.1"
ALPINE_GCC="$ALPINE_ROOT/usr/bin/gcc"

echo ""
echo "🔧 Creating PATH-based wrapper solution..."

# Create a dedicated wrapper directory
WRAPPER_DIR="$PWD/.local/alpine_wrappers"
mkdir -p "$WRAPPER_DIR"

# Create wrapper for cc1 that gets found by PATH
cat > "$WRAPPER_DIR/cc1" << EOF
#!/bin/bash
# PATH-based cc1 wrapper for Alpine GCC

ALPINE_ROOT="$PWD/.local/alpine"
ALPINE_LD="\$ALPINE_ROOT/lib/ld-musl-x86_64.so.1"
CC1_ORIG="\$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0/cc1"

# Set up Alpine environment
export LD_LIBRARY_PATH="\$ALPINE_ROOT/lib:\$ALPINE_ROOT/usr/lib:\${LD_LIBRARY_PATH:-}"

# Execute original cc1 with Alpine dynamic linker
exec "\$ALPINE_LD" "\$CC1_ORIG" "\$@"
EOF
chmod +x "$WRAPPER_DIR/cc1"

# Create wrapper for collect2
cat > "$WRAPPER_DIR/collect2" << EOF
#!/bin/bash
# PATH-based collect2 wrapper for Alpine GCC

ALPINE_ROOT="$PWD/.local/alpine"
ALPINE_LD="\$ALPINE_ROOT/lib/ld-musl-x86_64.so.1"
COLLECT2_ORIG="\$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0/collect2"

# Set up Alpine environment
export LD_LIBRARY_PATH="\$ALPINE_ROOT/lib:\$ALPINE_ROOT/usr/lib:\${LD_LIBRARY_PATH:-}"

# Execute original collect2 with Alpine dynamic linker
exec "\$ALPINE_LD" "\$COLLECT2_ORIG" "\$@"
EOF
chmod +x "$WRAPPER_DIR/collect2"

# Create wrapper for ld (linker)
cat > "$WRAPPER_DIR/ld" << EOF
#!/bin/bash
# PATH-based ld wrapper for Alpine GCC

ALPINE_ROOT="$PWD/.local/alpine"
ALPINE_LD="\$ALPINE_ROOT/lib/ld-musl-x86_64.so.1"
LD_ORIG="\$ALPINE_ROOT/usr/bin/ld"

# Check if Alpine ld exists, otherwise use system ld
if [ -f "\$LD_ORIG" ]; then
    # Set up Alpine environment
    export LD_LIBRARY_PATH="\$ALPINE_ROOT/lib:\$ALPINE_ROOT/usr/lib:\${LD_LIBRARY_PATH:-}"
    exec "\$ALPINE_LD" "\$LD_ORIG" "\$@"
else
    # Fall back to system ld
    exec /usr/bin/ld "\$@"
fi
EOF
chmod +x "$WRAPPER_DIR/ld"

echo "✅ Created PATH-based wrappers"

echo ""
echo "🧪 Testing PATH-based solution..."

# Set up a controlled environment with our wrappers first in PATH
export PATH="$WRAPPER_DIR:$PATH"
export LD_LIBRARY_PATH="$ALPINE_ROOT/lib:$ALPINE_ROOT/usr/lib:${LD_LIBRARY_PATH:-}"

echo "🔧 Using PATH: $PATH"
echo "🔧 Testing gcc compilation with PATH wrappers..."

if "$ALPINE_LD" "$ALPINE_GCC" tests/test_compile.c -o test_path_solution 2>&1; then
    echo ""
    echo "🎉 SUCCESS! PATH-based solution worked!"
    echo "🚀 Running the compiled program..."
    "$ALPINE_LD" ./test_path_solution
    echo ""
    echo "✅ Complete success! Alpine GCC is now fully functional!"
    echo ""
    echo "📋 To use this solution:"
    echo "   export PATH=\"$WRAPPER_DIR:\$PATH\""
    echo "   export LD_LIBRARY_PATH=\"$ALPINE_ROOT/lib:$ALPINE_ROOT/usr/lib:\$LD_LIBRARY_PATH\""
    echo "   $ALPINE_LD $ALPINE_GCC your_file.c -o your_program"
else
    echo ""
    echo "❌ PATH-based solution also failed"
    echo "🔍 This indicates a deeper incompatibility issue"
    
    echo ""
    echo "🔧 Final diagnostic - checking what cc1 actually needs..."
    echo "Checking Alpine cc1 binary details:"
    if command -v ldd >/dev/null 2>&1; then
        ldd "$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0/cc1" 2>/dev/null || echo "ldd failed - this is expected for musl binaries"
    fi
    
    echo ""
    echo "Trying to run cc1 directly with Alpine loader:"
    "$ALPINE_LD" "$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0/cc1" --version 2>&1 | head -5 || echo "cc1 direct execution failed"
fi

echo ""
echo "=================================================="
echo "📊 Final Analysis:"
echo "=================================================="
echo ""
echo "🔍 Root cause: musl/glibc fundamental incompatibility"
echo "💡 Working solutions:"
echo "   1. ✅ Use system GCC (immediate fix)"
echo "   2. ✅ Use containers (best practice)" 
echo "   3. ✅ Use chroot environment (complete isolation)"
echo ""
echo "🚫 Limitations of local solutions:"
echo "   • Alpine binaries require musl runtime environment"
echo "   • glibc systems can't natively run musl binaries"
echo "   • Even with dynamic linker, some system calls differ"
echo ""
echo "🏆 Recommended approach:"
echo "   Use apk-local for package discovery and management,"
echo "   but use system GCC or containers for actual compilation."