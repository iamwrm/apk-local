#!/bin/bash
# alpine-env.sh - Docker-free Alpine environment using bubblewrap

ALPINE_VERSION="${ALPINE_VERSION:-3.21}"
ALPINE_ARCH=$(uname -m)
ALPINE_ROOT="$HOME/.local/alpine-env"

# Detect container environment and check bubblewrap
check_env() {
    if ! command -v bwrap >/dev/null 2>&1; then
        echo "❌ bubblewrap not installed. Install: sudo apt install bubblewrap"
        return 1
    fi
    
    if ! bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --unshare-all --die-with-parent true >/dev/null 2>&1; then
        echo "❌ bubblewrap cannot create namespaces"
        if [ -f /.dockerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
            echo "🐳 Container detected. Run on host system or use --privileged"
        else
            echo "💡 Try: echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/00-local-userns.conf && sudo sysctl --system"
        fi
        return 1
    fi
}

# Set Alpine URL based on version
set_alpine_url() {
    case "$1" in
        edge) ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/edge/releases/${ALPINE_ARCH}/alpine-minirootfs-20250108-${ALPINE_ARCH}.tar.gz" ;;
        latest-stable) ALPINE_VERSION="3.22"; set_alpine_url "v3.22" ;;
        v*) ALPINE_VERSION="${1#v}"; ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ALPINE_ARCH}/alpine-minirootfs-${ALPINE_VERSION}.0-${ALPINE_ARCH}.tar.gz" ;;
        *) echo "❌ Unknown channel: $1. Available: v3.19, v3.20, v3.21, v3.22, edge, latest-stable"; return 1 ;;
    esac
}

# Setup Alpine environment
setup_alpine() {
    check_env || return 1
    mkdir -p "$ALPINE_ROOT"
    
    if [ ! -f "$ALPINE_ROOT/bin/busybox" ]; then
        echo "Downloading Alpine $ALPINE_VERSION..."
        if command -v curl >/dev/null 2>&1; then
            curl -sL "$ALPINE_URL" | tar -xz -C "$ALPINE_ROOT"
        elif command -v wget >/dev/null 2>&1; then
            wget -qO- "$ALPINE_URL" | tar -xz -C "$ALPINE_ROOT"
        else
            echo "❌ Need curl or wget"; return 1
        fi
        
        mkdir -p "$ALPINE_ROOT"/{tmp,var/tmp,var/cache/apk,etc/apk}
        [ -f /etc/resolv.conf ] && cp /etc/resolv.conf "$ALPINE_ROOT/etc/resolv.conf"
        
        echo "Installing development tools..."
        run_bwrap /sbin/apk add --no-cache gcc g++ musl-dev make cmake pkgconfig
    fi
}

# Run command with bubblewrap
run_bwrap() {
    bwrap \
        --bind "$ALPINE_ROOT" / \
        --dev /dev --proc /proc --tmpfs /tmp --tmpfs /var/tmp --tmpfs /run \
        --bind "$PWD" /tmp/workspace --chdir /tmp/workspace \
        --ro-bind /etc/resolv.conf /etc/resolv.conf \
        --setenv PATH "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        --setenv HOME "/tmp/workspace" \
        --unshare-all --share-net --die-with-parent \
        "$@"
}

# Main command handler
case "${1:-help}" in
    setup)
        [ $# -lt 2 ] && { echo "Usage: $0 setup <channel>"; echo "Channels: v3.19, v3.20, v3.21, v3.22, edge, latest-stable"; exit 1; }
        set_alpine_url "$2" || exit 1
        echo "🏔️ Setting up Alpine $2..."
        [ -d "$ALPINE_ROOT" ] && { echo "🗑️ Removing existing environment..."; rm -rf "$ALPINE_ROOT"; }
        setup_alpine && echo "✅ Alpine $2 setup complete!"
        ;;
    run)
        shift; [ $# -eq 0 ] && { echo "Usage: $0 run <command> [args...]"; exit 1; }
        [ ! -f "$ALPINE_ROOT/bin/busybox" ] && {
            echo "Setting up Alpine environment (default: $ALPINE_VERSION)..."
            echo "💡 Use '$0 setup <channel>' to choose a different version"
            set_alpine_url "v$ALPINE_VERSION" && setup_alpine
        }
        check_env && run_bwrap "$@"
        ;;
    *)
        cat << 'EOF'
Usage: alpine-env.sh {setup|run} <args...>

Commands:
  setup <channel>    - Set up Alpine environment
  run <cmd> [args]   - Run command in Alpine environment

Channels: v3.19, v3.20, v3.21, v3.22, edge, latest-stable

Examples:
  alpine-env.sh setup edge              # Set up Alpine edge
  alpine-env.sh run gcc hello.c -o hello # Compile with Alpine GCC
  alpine-env.sh run apk add nodejs       # Install packages
  alpine-env.sh run /bin/sh              # Get Alpine shell

Requirements: bubblewrap (sudo apt install bubblewrap)
EOF
        ;;
esac