#!/bin/bash
set -euo pipefail

echo "🔧 Fixing Alpine GCC - Creating Dynamic Linker Wrappers"
echo "======================================================="

ALPINE_ROOT=".local/alpine"
ALPINE_LD="$ALPINE_ROOT/lib/ld-musl-x86_64.so.1"
ALPINE_GCC_DIR="$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0"

# Check if Alpine environment exists
if [ ! -d "$ALPINE_ROOT" ]; then
    echo "❌ Alpine environment not found. Run 'apk-local manager add gcc musl-dev' first"
    exit 1
fi

if [ ! -f "$ALPINE_LD" ]; then
    echo "❌ Alpine dynamic linker not found at $ALPINE_LD"
    exit 1
fi

echo "📁 Working with Alpine GCC directory: $ALPINE_GCC_DIR"

# Create backup directory
BACKUP_DIR="$ALPINE_GCC_DIR/original_binaries"
mkdir -p "$BACKUP_DIR"

# Function to create wrapper script
create_wrapper() {
    local binary_name="$1"
    local binary_path="$ALPINE_GCC_DIR/$binary_name"
    local backup_path="$BACKUP_DIR/$binary_name"
    
    if [ ! -f "$binary_path" ]; then
        echo "⚠️  Binary $binary_name not found, skipping..."
        return
    fi
    
    # Skip if already wrapped (check if it's a script)
    if file "$binary_path" | grep -q "script\|text"; then
        echo "✅ $binary_name already wrapped, skipping..."
        return
    fi
    
    echo "🔧 Creating wrapper for $binary_name..."
    
    # Backup original binary
    cp "$binary_path" "$backup_path"
    
    # Create wrapper script
    cat > "$binary_path" << EOF
#!/bin/bash
# Auto-generated wrapper for Alpine GCC $binary_name
# This ensures the binary runs with the Alpine dynamic linker

ALPINE_LD="$PWD/$ALPINE_LD"
ORIGINAL_BINARY="$PWD/$backup_path"

# Set up Alpine environment
export LD_LIBRARY_PATH="$PWD/$ALPINE_ROOT/lib:$PWD/$ALPINE_ROOT/usr/lib:\${LD_LIBRARY_PATH:-}"

# Execute original binary with Alpine dynamic linker
exec "\$ALPINE_LD" "\$ORIGINAL_BINARY" "\$@"
EOF
    
    chmod +x "$binary_path"
    echo "✅ Created wrapper for $binary_name"
}

# Create wrappers for all GCC binaries
echo ""
echo "🔧 Creating wrappers for GCC subsystem binaries..."

# Core compilation binaries
create_wrapper "cc1"
create_wrapper "cc1plus"
create_wrapper "cc1obj" 
create_wrapper "collect2"
create_wrapper "lto1"
create_wrapper "lto-wrapper"
create_wrapper "g++-mapper-server"

# Also wrap the main gcc binary for consistency
echo ""
echo "🔧 Creating wrapper for main gcc binary..."
GCC_BINARY="$ALPINE_ROOT/usr/bin/gcc"
GCC_BACKUP="$ALPINE_ROOT/usr/bin/gcc.original"

if [ -f "$GCC_BINARY" ] && ! file "$GCC_BINARY" | grep -q "script\|text"; then
    cp "$GCC_BINARY" "$GCC_BACKUP"
    
    cat > "$GCC_BINARY" << EOF
#!/bin/bash
# Auto-generated wrapper for Alpine GCC main binary
# This ensures all subprocesses use the Alpine environment

ALPINE_LD="$PWD/$ALPINE_LD"
ORIGINAL_GCC="$PWD/$GCC_BACKUP"

# Set up comprehensive Alpine environment
export LD_LIBRARY_PATH="$PWD/$ALPINE_ROOT/lib:$PWD/$ALPINE_ROOT/usr/lib:\${LD_LIBRARY_PATH:-}"
export PATH="$PWD/$ALPINE_ROOT/usr/bin:$PWD/$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0:\$PATH"

# For debugging (uncomment to see what's happening)
# echo "🔧 Alpine GCC wrapper executing: \$ALPINE_LD \$ORIGINAL_GCC \$@" >&2

# Execute original GCC with Alpine dynamic linker
exec "\$ALPINE_LD" "\$ORIGINAL_GCC" "\$@"
EOF
    
    chmod +x "$GCC_BINARY"
    echo "✅ Created wrapper for main gcc binary"
fi

echo ""
echo "🔧 Creating enhanced apk-local gcc environment command..."

# Create an enhanced version of the gcc command
cat > "gcc-alpine" << EOF
#!/bin/bash
# Enhanced Alpine GCC runner with complete environment setup

ALPINE_ROOT="$PWD/$ALPINE_ROOT"
ALPINE_LD="\$ALPINE_ROOT/lib/ld-musl-x86_64.so.1"
ALPINE_GCC="\$ALPINE_ROOT/usr/bin/gcc"

# Set up complete Alpine environment for all subprocesses
export LD_LIBRARY_PATH="\$ALPINE_ROOT/lib:\$ALPINE_ROOT/usr/lib:\${LD_LIBRARY_PATH:-}"
export PATH="\$ALPINE_ROOT/usr/bin:\$ALPINE_ROOT/usr/libexec/gcc/x86_64-alpine-linux-musl/14.3.0:\$PATH"

# Also try setting the interpreter directly for exec calls
export LD_LOADER="\$ALPINE_LD"

echo "🏔️  Using Alpine GCC with fixed environment..." >&2

# Execute with Alpine dynamic linker
exec "\$ALPINE_LD" "\$ALPINE_GCC" "\$@"
EOF

chmod +x "gcc-alpine"

echo ""
echo "=================================================="
echo "✅ Alpine GCC Fix Complete!"
echo "=================================================="
echo ""
echo "📋 What was done:"
echo "   • Created wrapper scripts for all GCC subsystem binaries"
echo "   • Each wrapper ensures binaries run with Alpine dynamic linker"
echo "   • Backed up original binaries to $BACKUP_DIR"
echo "   • Created 'gcc-alpine' enhanced command"
echo ""
echo "🧪 Test the fix:"
echo "   ./gcc-alpine tests/test_compile.c -o test_fixed"
echo "   apk-local env gcc tests/test_compile.c -o test_fixed"
echo ""
echo "🔄 To revert changes:"
echo "   cp $BACKUP_DIR/* $ALPINE_GCC_DIR/"
echo "   cp $GCC_BACKUP $GCC_BINARY"