#!/bin/bash

set -e

# Default values
PACKAGE=""
BINARY=""
OUTPUT_DIR=""

# Parse command line arguments
while getopts "b:d:" opt; do
    case $opt in
        b)
            BINARY="$OPTARG"
            ;;
        d)
            OUTPUT_DIR="$OPTARG"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Shift to get remaining arguments
shift $((OPTIND-1))

# Check if package name is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [-b binary_name] [-d output_dir] <package_name>"
    echo "Example: $0 -b vim -d vim_exe vim"
    echo "Options:"
    echo "  -b binary_name   Name of the binary to extract (default: same as package)"
    echo "  -d output_dir    Output directory (default: package_exe)"
    exit 1
fi

PACKAGE="$1"

# Set defaults if not provided
if [ -z "$BINARY" ]; then
    BINARY="$PACKAGE"
fi

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="${PACKAGE}_exe"
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run Debian testing container and extract the binary with dependencies
docker run --rm -v "$(pwd)/$OUTPUT_DIR:/output" -e PACKAGE="$PACKAGE" -e BINARY="$BINARY" debian:testing bash -c "
    set -e
    
    # Update package list
    apt-get update -qq
    
    # Install the package
    apt-get install -y --no-install-recommends $PACKAGE
    
    # For gcc, also install binutils
    if [ \"$PACKAGE\" = \"gcc\" ]; then
        apt-get install -y --no-install-recommends binutils
    fi
    
    # Find the main binary
    BINARY_PATH=\$(which $BINARY)
    if [ -z \"\$BINARY_PATH\" ]; then
        echo 'Error: Binary $BINARY not found'
        exit 1
    fi
    
    echo \"Found binary: \$BINARY_PATH\"
    
    # Create directory structure in output
    mkdir -p /output/lib
    mkdir -p /output/bin
    
    # Copy the binary
    cp \$BINARY_PATH /output/bin/$BINARY
    
    # Special handling for gcc
    if [ \"$PACKAGE\" = \"gcc\" ] || [ \"$BINARY\" = \"gcc\" ]; then
        echo \"Detected GCC - copying additional components...\"
        
        # Find gcc version and target
        GCC_VERSION=\$($BINARY -dumpversion)
        GCC_TARGET=\$($BINARY -dumpmachine)
        GCC_LIBDIR=\"/usr/lib/gcc/\$GCC_TARGET/\$GCC_VERSION\"
        
        echo \"GCC version: \$GCC_VERSION\"
        echo \"GCC target: \$GCC_TARGET\"
        echo \"GCC libdir: \$GCC_LIBDIR\"
        
        # Create gcc directory structure
        mkdir -p /output/usr/lib/gcc/\$GCC_TARGET/\$GCC_VERSION
        mkdir -p /output/usr/libexec/gcc/\$GCC_TARGET/\$GCC_VERSION
        mkdir -p /output/usr/bin
        
        # Copy gcc internal binaries from libexec
        GCC_LIBEXEC=\"/usr/libexec/gcc/\$GCC_TARGET/\$GCC_VERSION\"
        if [ -d \"\$GCC_LIBEXEC\" ]; then
            echo \"Copying gcc internals from \$GCC_LIBEXEC...\"
            cp -r \$GCC_LIBEXEC/* /output/usr/libexec/gcc/\$GCC_TARGET/\$GCC_VERSION/
        fi
        
        # Copy gcc libraries
        if [ -d \"\$GCC_LIBDIR\" ]; then
            cp -r \$GCC_LIBDIR/* /output/usr/lib/gcc/\$GCC_TARGET/\$GCC_VERSION/
        fi
        
        # Copy related binaries
        for tool in cpp g++ c++ gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool as ld; do
            if which \$tool >/dev/null 2>&1; then
                echo \"Copying \$tool...\"
                cp \$(which \$tool) /output/usr/bin/ 2>/dev/null || true
            fi
        done
        
        # Copy binutils if installed
        for tool in ar nm objcopy objdump ranlib readelf strip; do
            if which \$tool >/dev/null 2>&1; then
                echo \"Copying \$tool...\"
                cp \$(which \$tool) /output/usr/bin/ 2>/dev/null || true
            fi
        done
        
        # Store gcc paths for wrapper
        echo \"GCC_VERSION=\$GCC_VERSION\" > /output/gcc_info
        echo \"GCC_TARGET=\$GCC_TARGET\" >> /output/gcc_info
    fi
    
    # Get all dynamic dependencies for all binaries
    ALL_BINARIES=\"\$BINARY_PATH\"
    if [ -d /output/usr/bin ]; then
        ALL_BINARIES=\"\$ALL_BINARIES \$(find /output/usr/bin -type f -executable)\"
    fi
    if [ -d /output/usr/lib ]; then
        ALL_BINARIES=\"\$ALL_BINARIES \$(find /output/usr/lib -type f -executable)\"
    fi
    if [ -d /output/usr/libexec ]; then
        ALL_BINARIES=\"\$ALL_BINARIES \$(find /output/usr/libexec -type f -executable)\"
    fi
    
    # Collect all dependencies
    DEPS=\"\"
    for binary in \$ALL_BINARIES; do
        if [ -f \"\$binary\" ]; then
            BINARY_DEPS=\$(ldd \$binary 2>/dev/null | grep -E '=> /' | awk '{print \$3}' | sort -u)
            DEPS=\"\$DEPS \$BINARY_DEPS\"
        fi
    done
    DEPS=\$(echo \$DEPS | tr ' ' '\n' | sort -u)
    
    # Get the dynamic linker from main binary
    LINKER=\$(ldd \$BINARY_PATH | grep -E '/ld-linux' | awk '{print \$1}')
    if [ -z \"\$LINKER\" ]; then
        LINKER=\$(ldd \$BINARY_PATH | grep -E 'ld-' | grep -v '=>' | awk '{print \$1}')
    fi
    
    echo \"Dynamic linker: \$LINKER\"
    
    # Copy the dynamic linker
    if [ -n \"\$LINKER\" ]; then
        cp \$LINKER /output/
        chmod +x /output/\$(basename \$LINKER)
    fi
    
    # Copy all dependencies
    for dep in \$DEPS; do
        if [ -f \"\$dep\" ]; then
            echo \"Copying dependency: \$dep\"
            cp \$dep /output/lib/
        fi
    done
    
    # Also check for additional runtime dependencies
    for dep in \$DEPS; do
        if [ -f \"\$dep\" ]; then
            SUBDEPS=\$(ldd \$dep 2>/dev/null | grep -E '=> /' | awk '{print \$3}' | sort -u)
            for subdep in \$SUBDEPS; do
                if [ -f \"\$subdep\" ] && [ ! -f \"/output/lib/\$(basename \$subdep)\" ]; then
                    echo \"Copying subdependency: \$subdep\"
                    cp \$subdep /output/lib/
                fi
            done
        fi
    done
    
"

# Fix permissions on the host
echo "Fixing permissions..."
sudo chown -R $(id -u):$(id -g) "$OUTPUT_DIR"/*
chmod -R u+rw "$OUTPUT_DIR"/*
find "$OUTPUT_DIR" -type f -executable -exec chmod u+x {} \;

# Create the wrapper script
LINKER_NAME=$(ls "$OUTPUT_DIR"/ld-* 2>/dev/null | head -1 | xargs basename)
if [ -z "$LINKER_NAME" ]; then
    echo "Error: Dynamic linker not found"
    exit 1
fi

# Check if this is gcc to create appropriate wrapper
if [ -f "$OUTPUT_DIR/gcc_info" ]; then
    # Load gcc info
    source "$OUTPUT_DIR/gcc_info"
    
cat > "$OUTPUT_DIR/$BINARY" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set up GCC environment
export PATH="$SCRIPT_DIR/usr/bin:$PATH"
export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:$LD_LIBRARY_PATH"

# Run gcc with proper paths
exec "$SCRIPT_DIR/LINKER_NAME_PLACEHOLDER" --library-path "$SCRIPT_DIR/lib" "$SCRIPT_DIR/bin/BINARY_NAME_PLACEHOLDER" -B"$SCRIPT_DIR/usr/bin/" -B"$SCRIPT_DIR/usr/lib/gcc/GCC_TARGET_PLACEHOLDER/GCC_VERSION_PLACEHOLDER/" -B"$SCRIPT_DIR/usr/libexec/gcc/GCC_TARGET_PLACEHOLDER/GCC_VERSION_PLACEHOLDER/" "$@"
EOF

# Replace placeholders
sed -i "s/LINKER_NAME_PLACEHOLDER/$LINKER_NAME/g" "$OUTPUT_DIR/$BINARY"
sed -i "s/BINARY_NAME_PLACEHOLDER/$BINARY/g" "$OUTPUT_DIR/$BINARY"
sed -i "s/GCC_TARGET_PLACEHOLDER/$GCC_TARGET/g" "$OUTPUT_DIR/$BINARY"
sed -i "s/GCC_VERSION_PLACEHOLDER/$GCC_VERSION/g" "$OUTPUT_DIR/$BINARY"
else
    # Standard wrapper for non-gcc binaries
cat > "$OUTPUT_DIR/$BINARY" << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$SCRIPT_DIR/$LINKER_NAME" --library-path "\$SCRIPT_DIR/lib" "\$SCRIPT_DIR/bin/$BINARY" "\$@"
EOF
fi

chmod +x "$OUTPUT_DIR/$BINARY"

echo "Portable $BINARY created in $OUTPUT_DIR/"
echo "Run with: $OUTPUT_DIR/$BINARY"