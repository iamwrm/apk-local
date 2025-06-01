#!/bin/bash
set -ueo pipefail

mkdir -p .local

PATH=$PWD:$PATH

apk-local manager add gcc musl-dev

echo '📋 Checking gcc version...'
apk-local env gcc --version
        
echo '🔨 Compiling test program...'
apk-local env gcc tests/test_compile.c -o test_compile
        
echo '🔍 Checking binary dependencies with ldd...'
apk-local env ldd test_compile || echo 'Note: ldd may not be available, checking with file command'
file test_compile
        
echo '🚀 Running compiled test program...'
./test_compile
        
echo '✅ All tests passed! Alpine GCC is fully functional.'
