#!/bin/bash
set -e

echo "🔬 Demonstration: LD_PRELOAD vs Dynamic Linker Selection"
echo "========================================================"
echo ""
echo "This demo shows WHY LD_PRELOAD cannot switch the dynamic linker"
echo ""

# Compile our demonstration LD_PRELOAD library
echo "📦 Compiling LD_PRELOAD demonstration library..."
gcc -shared -fPIC -o loader_test.so test_loader_switching.c -ldl
echo "✅ Library compiled: loader_test.so"
echo ""

# Create a simple test program
echo "📝 Creating test program..."
cat > test_program.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from test program!\n");
    printf("If you see this, the process started successfully.\n");
    return 0;
}
EOF

gcc -o test_program test_program.c
echo "✅ Test program compiled: test_program"
echo ""

# Test 1: Show LD_PRELOAD working normally
echo "🧪 Test 1: LD_PRELOAD with compatible binary (glibc → glibc)"
echo "============================================================"
echo "Command: LD_PRELOAD=./loader_test.so ./test_program"
echo ""
echo "Expected: LD_PRELOAD loads successfully, program runs"
echo "Output:"
LD_PRELOAD=./loader_test.so ./test_program
echo ""

# Check what dynamic linker our test program uses
echo "🔍 Checking our test program's dynamic linker:"
readelf -l test_program | grep -A1 INTERP || echo "No INTERP section (statically linked?)"
echo ""

# Test 2: Try with a hypothetical musl binary (simulate the failure)
echo "🧪 Test 2: What happens with incompatible binary (musl on glibc system)"
echo "======================================================================"
echo "Let's examine what would happen with an Alpine musl binary..."
echo ""

# Create a fake musl binary path for demonstration
mkdir -p fake_alpine/usr/bin
echo '#!/bin/bash' > fake_alpine/usr/bin/fake_musl_gcc
echo 'echo "This script simulates a musl binary that LD_PRELOAD never gets to intercept"' >> fake_alpine/usr/bin/fake_musl_gcc
chmod +x fake_alpine/usr/bin/fake_musl_gcc

echo "📋 If we had a real musl binary, it would contain:"
echo "   PT_INTERP: /lib/ld-musl-x86_64.so.1"
echo ""
echo "🚫 The execution timeline would be:"
echo "   1. execve('/path/to/musl_binary', ...)"
echo "   2. Kernel reads ELF header"
echo "   3. Kernel finds PT_INTERP: /lib/ld-musl-x86_64.so.1"
echo "   4. Kernel tries to load /lib/ld-musl-x86_64.so.1"
echo "   5. ❌ FAILURE - Linker not found or incompatible"
echo "   6. ❌ Process never starts"
echo "   7. ❌ LD_PRELOAD never gets a chance to run"
echo ""

# Test 3: Show that we can intercept execve for subprocess calls
echo "🧪 Test 3: LD_PRELOAD can intercept subprocess creation"
echo "======================================================"
echo "Command: LD_PRELOAD=./loader_test.so bash -c './test_program'"
echo ""
echo "Expected: LD_PRELOAD intercepts the execve() call to ./test_program"
echo "Output:"
LD_PRELOAD=./loader_test.so bash -c './test_program'
echo ""

# Show the key insight
echo "💡 Key Insights:"
echo "==============="
echo ""
echo "✅ LD_PRELOAD CAN:"
echo "   • Intercept execve() calls from running processes"
echo "   • Hook library functions after process starts"
echo "   • Modify behavior of successfully running programs"
echo ""
echo "❌ LD_PRELOAD CANNOT:"
echo "   • Change the dynamic linker chosen by the kernel"
echo "   • Rescue a process that fails to start due to missing/incompatible linker"
echo "   • Bridge ABI incompatibilities between musl and glibc"
echo ""
echo "🎯 The Timeline Problem:"
echo "   Kernel chooses loader → Process starts → LD_PRELOAD loads"
echo "                    ↑"
echo "              Failure happens HERE"
echo "              (before LD_PRELOAD)"
echo ""

# Cleanup
echo "🧹 Cleaning up..."
rm -f test_program test_program.c loader_test.so
rm -rf fake_alpine
echo ""

echo "🏁 Conclusion:"
echo "=============="
echo "LD_PRELOAD is powerful for process interception and library hooking,"
echo "but it cannot solve the fundamental timing issue with dynamic linker"
echo "selection. The kernel chooses the loader before LD_PRELOAD runs."
echo ""
echo "For Alpine GCC on Ubuntu, container-based solutions remain the"
echo "most practical approach."