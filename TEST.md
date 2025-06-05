# Compiler Test Results

Test results for `debian_portable.sh` compiler extraction on debian:testing (aarch64).

## Summary

| Compiler | Extraction | Compilation | Status |
|----------|------------|-------------|---------|
| **GCC**      | ✅ Success | ✅ Works    | **✅ Full Success** |
| **G++**      | ❌ Failed  | ❌ N/A      | **❌ Failed** |
| **Clang**    | ✅ Success | ❌ Failed   | **⚠️ Partial** |
| **Clang++**  | ❌ Failed  | ❌ N/A      | **❌ Failed** |
| **Go**       | ⚠️ Partial | ❌ N/A      | **⚠️ Partial** |

## Detailed Results

### ✅ GCC - gcc (Debian 14.2.0-19) 14.2.0
- **Extraction**: ✅ Complete with toolchain
- **Compilation**: ✅ C "Hello World" works
- **Command**: `./debian_portable.sh -b gcc -d gcc_test gcc`

### ❌ G++ - Extraction Failed  
- **Issue**: "Dynamic linker not found" error during extraction
- **Root Cause**: C++ stdlib dependency issues

### ⚠️ Clang - Debian clang version 19.1.7 (3)
- **Extraction**: ✅ Binary extracted successfully  
- **Issue**: Missing internal tools (-cc1), compilation fails
- **Error**: `clang: error: unable to execute command: No such file or directory`

### ❌ Clang++ - Package Issue
- **Issue**: `clang++` bundled in `clang` package, not standalone
- **Status**: Extraction failed due to package name mismatch

### ⚠️ Go - Static Binary Challenge
- **Extraction**: ⚠️ Binary extracted but script fails at wrapper
- **Issue**: Go is statically linked, doesn't need dynamic linker
- **Error**: `go: cannot find GOROOT directory`

## Key Issues

1. **C++ Compilers**: Need proper stdlib extraction (g++, clang++)
2. **Clang Toolchain**: Missing internal components (-cc1, etc.)
3. **Static Binaries**: Go needs different handling (no dynamic linking)
4. **Package Mapping**: Some binaries bundled in parent packages

## Script Improvements (241→114 lines, 53% reduction)

- Modular functions: `parse_args`, `extract_binary`, `fix_permissions`, `create_wrapper`
- Multi-compiler support with dependencies
- Improved error handling and wrapper generation
- Updated CI/CD and documentation