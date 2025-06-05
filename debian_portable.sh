#!/bin/bash

# set -e

# Default values
PACKAGE=""
BINARY=""
OUTPUT_DIR=""

usage() {
    echo "Usage: $0 [-b binary_name] [-d output_dir] <package_name>"
    echo "Example: $0 -b vim -d vim_exe vim"
    echo "Options:"
    echo "  -b binary_name   Name of the binary to extract (default: same as package)"
    echo "  -d output_dir    Output directory (default: package_exe)"
    exit 1
}

parse_args() {
    while getopts "b:d:" opt; do
        case $opt in
            b) BINARY="$OPTARG" ;;
            d) OUTPUT_DIR="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        esac
    done
    shift $((OPTIND-1))
    
    [ $# -eq 0 ] && usage
    PACKAGE="$1"
    
    [ -z "$BINARY" ] && BINARY="$PACKAGE"
    [ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="${PACKAGE}_exe"
}


extract_binary() {
    mkdir -p "$OUTPUT_DIR"
    docker run --rm -v "$(pwd)/$OUTPUT_DIR:/output" -e PACKAGE="$PACKAGE" -e BINARY="$BINARY" debian:testing bash -c '
        set -e
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y --no-install-recommends $PACKAGE >/dev/null 2>&1
        # Install additional dependencies for compilers
        case "$PACKAGE" in
            gcc) apt-get install -y --no-install-recommends binutils libc6-dev >/dev/null 2>&1 ;;
            g++) apt-get install -y --no-install-recommends binutils libc6-dev libstdc++-dev >/dev/null 2>&1 ;;
            clang) apt-get install -y --no-install-recommends binutils libc6-dev >/dev/null 2>&1 ;;
            clang++) apt-get install -y --no-install-recommends binutils libc6-dev libstdc++-dev >/dev/null 2>&1 ;;
            golang-go) apt-get install -y --no-install-recommends libc6-dev >/dev/null 2>&1 ;;
        esac
        
        mkdir -p /output/lib /output/bin
        BINARY_PATH=$(which $BINARY)
        [ -z "$BINARY_PATH" ] && { echo "Error: Binary $BINARY not found"; exit 1; }
        cp $BINARY_PATH /output/bin/$BINARY
        
        if [ "$PACKAGE" = "gcc" ] || [ "$BINARY" = "gcc" ] || [ "$BINARY" = "g++" ] || [ "$PACKAGE" = "g++" ]; then
            GCC_VERSION=$($BINARY -dumpversion)
            GCC_TARGET=$($BINARY -dumpmachine)
            mkdir -p /output/usr/{lib/gcc/$GCC_TARGET/$GCC_VERSION,libexec/gcc/$GCC_TARGET/$GCC_VERSION,bin}
            [ -d "/usr/libexec/gcc/$GCC_TARGET/$GCC_VERSION" ] && cp -r /usr/libexec/gcc/$GCC_TARGET/$GCC_VERSION/* /output/usr/libexec/gcc/$GCC_TARGET/$GCC_VERSION/
            [ -d "/usr/lib/gcc/$GCC_TARGET/$GCC_VERSION" ] && cp -r /usr/lib/gcc/$GCC_TARGET/$GCC_VERSION/* /output/usr/lib/gcc/$GCC_TARGET/$GCC_VERSION/
            for tool in cpp g++ c++ gcc-ar gcc-nm gcc-ranlib gcov gcov-dump gcov-tool as ld ar nm objcopy objdump ranlib readelf strip; do
                which $tool >/dev/null 2>&1 && cp $(which $tool) /output/usr/bin/ 2>/dev/null || true
            done
            printf "GCC_VERSION=%s\nGCC_TARGET=%s\n" "$GCC_VERSION" "$GCC_TARGET" > /output/gcc_info
        fi
        
        ALL_BINARIES="$BINARY_PATH $(find /output/usr -type f -executable 2>/dev/null || true)"
        DEPS=""
        for binary in $ALL_BINARIES; do
            [ -f "$binary" ] && DEPS="$DEPS $(ldd $binary 2>/dev/null | grep -E '"'"'=> /'"'"' | awk '"'"'{print $3}'"'"')"
        done
        DEPS=$(echo $DEPS | tr '"'"' '"'"' '"'"'\n'"'"' | sort -u)
        
        LINKER=$(ldd $BINARY_PATH | grep -E '"'"'/(ld-linux|ld-)'"'"' | grep -v '"'"'=>'"'"' | awk '"'"'{print $1}'"'"' | head -1)
        [ -n "$LINKER" ] && { cp $LINKER /output/; chmod +x /output/$(basename $LINKER); }
        
        for dep in $DEPS; do
            [ -f "$dep" ] && cp $dep /output/lib/
        done
        
        for dep in $DEPS; do
            [ -f "$dep" ] && ldd $dep 2>/dev/null | grep -E '"'"'=> /'"'"' | awk '"'"'{print $3}'"'"' | while read subdep; do
                [ -f "$subdep" ] && [ ! -f "/output/lib/$(basename $subdep)" ] && cp $subdep /output/lib/
            done
        done
    '
}

fix_permissions() {
    echo "Fixing permissions..."
    sudo chown -R $(id -u):$(id -g) "$OUTPUT_DIR"/*
    chmod -R u+rw "$OUTPUT_DIR"/*
    find "$OUTPUT_DIR" -type f -executable -exec chmod u+x {} \;
}

create_wrapper() {
    local linker_name=$(ls "$OUTPUT_DIR"/ld-* 2>/dev/null | head -1 | xargs basename)
    [ -z "$linker_name" ] && { echo "Error: Dynamic linker not found"; exit 1; }
    
    if [ -f "$OUTPUT_DIR/gcc_info" ]; then
        source "$OUTPUT_DIR/gcc_info"
        printf '#!/bin/bash\nSCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\nexport PATH="$SCRIPT_DIR/usr/bin:$PATH"\nexport LD_LIBRARY_PATH="$SCRIPT_DIR/lib:$LD_LIBRARY_PATH"\nexec "$SCRIPT_DIR/%s" --library-path "$SCRIPT_DIR/lib" "$SCRIPT_DIR/bin/%s" -B"$SCRIPT_DIR/usr/bin/" -B"$SCRIPT_DIR/usr/lib/gcc/%s/%s/" -B"$SCRIPT_DIR/usr/libexec/gcc/%s/%s/" "$@"\n' "$linker_name" "$BINARY" "$GCC_TARGET" "$GCC_VERSION" "$GCC_TARGET" "$GCC_VERSION" > "$OUTPUT_DIR/$BINARY"
    else
        printf '#!/bin/bash\nSCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"\nexec "$SCRIPT_DIR/%s" --library-path "$SCRIPT_DIR/lib" "$SCRIPT_DIR/bin/%s" "$@"\n' "$linker_name" "$BINARY" > "$OUTPUT_DIR/$BINARY"
    fi
    
    chmod +x "$OUTPUT_DIR/$BINARY"
    echo "Portable $BINARY created in $OUTPUT_DIR/"
    echo "Run with: $OUTPUT_DIR/$BINARY"
}

main() {
    parse_args "$@"
    extract_binary
    fix_permissions
    create_wrapper
}

main "$@"