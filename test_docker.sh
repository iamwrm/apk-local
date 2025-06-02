#!/bin/bash
set -ueo pipefail

echo "🐳 Docker Container Test for Alpine Environment"
echo "=============================================="

mkdir -p .local

cat <<EOF > .local/Dockerfile
FROM debian:12-slim
RUN apt-get update && apt-get install -y curl bubblewrap file
WORKDIR /app
EOF

echo "🔨 Building test container..."
docker build -t alpine-env-test .local

echo ""
echo "🚀 Running container test..."
echo ""

# Run the container test
docker run --rm -v "$PWD:/app" alpine-env-test bash -c "
echo '🐳 Inside Docker Container'
echo '========================='
echo ''

# Run our container test script
bash /app/test_container.sh
"

echo ""
echo "🏠 Testing on Host System"
echo "========================"
echo ""

# Test if it works on the host
if command -v bwrap >/dev/null 2>&1; then
    if bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --unshare-all --die-with-parent true >/dev/null 2>&1; then
        echo "✅ bubblewrap works on host system"
        echo "🏔️ Running quick Alpine test on host..."
        ./alpine-env.sh run echo "Alpine environment works on host!"
    else
        echo "❌ bubblewrap doesn't work on host either"
        echo "💡 Check kernel user namespace settings"
    fi
else
    echo "ℹ️  bubblewrap not installed on host"
    echo "📦 Install with: sudo apt install bubblewrap"
fi

echo ""
echo "📋 Summary"
echo "=========="
echo "• Container environments typically disable user namespaces for security"
echo "• alpine-env.sh works best on host systems with bubblewrap support"
echo "• For CI/CD, run alpine-env.sh on the runner host, not inside containers"
echo "• Docker Desktop may provide better namespace support than standard Docker" 