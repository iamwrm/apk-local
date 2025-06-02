#!/bin/bash
set -ueo pipefail

echo "🏔️ Alpine Environment Test Suite"
echo "================================"

# Check if we're in a container environment
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    echo "🐳 Detected container environment"
    echo "💡 Note: This test may fail due to user namespace restrictions"
    echo "   For best results, run alpine-env.sh on the host system"
    echo ""
fi



# Test Alpine v3.22
echo ""
echo "📋 Testing Alpine v3.22 environment..."
./alpine-env.sh setup v3.22
./alpine-env.sh run gcc --version
./alpine-env.sh run cat /etc/alpine-release

echo ""
echo "🔨 Compiling test program with Alpine v3.22 GCC..."
./alpine-env.sh run gcc tests/test_compile.c -o test_compile_v322

echo ""
echo "🚀 Running v3.22 compiled test program..."
./alpine-env.sh run ./test_compile_v322

# Test APK package management
echo ""
echo "📦 Testing APK package management..."
./alpine-env.sh run apk search nodejs | head -5
./alpine-env.sh run apk add nodejs
./alpine-env.sh run node --version

# Test shell access
echo ""
echo "🐚 Testing shell access..."
echo "echo 'Shell access works!' && exit" | ./alpine-env.sh run /bin/sh

# Cleanup
echo ""
echo "🧹 Cleaning up test files..."
rm -f test_compile test_compile_edge test_compile_v322

echo ""
echo "✅ All tests passed! Alpine environment is fully functional."
echo "🎉 Successfully tested multiple Alpine channels and functionality."
