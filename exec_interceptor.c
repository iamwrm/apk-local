#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <sys/wait.h>

// Function pointer for the real execve
static int (*real_execve)(const char *pathname, char *const argv[], char *const envp[]) = NULL;

// Check if a binary is an Alpine musl binary
static int is_alpine_binary(const char *pathname) {
    // Check if it's in our Alpine directory
    if (strstr(pathname, ".local/alpine/") != NULL) {
        return 1;
    }
    
    // Check for specific GCC binaries
    if (strstr(pathname, "cc1") != NULL || 
        strstr(pathname, "collect2") != NULL ||
        strstr(pathname, "lto1") != NULL ||
        strstr(pathname, "lto-wrapper") != NULL) {
        return 1;
    }
    
    return 0;
}

// Intercepted execve function
int execve(const char *pathname, char *const argv[], char *const envp[]) {
    // Load the real execve if not already loaded
    if (!real_execve) {
        real_execve = dlsym(RTLD_NEXT, "execve");
        if (!real_execve) {
            fprintf(stderr, "Error: Could not load real execve\n");
            return -1;
        }
    }
    
    // Check if this is an Alpine binary that needs the dynamic linker
    if (is_alpine_binary(pathname)) {
        fprintf(stderr, "🔧 Intercepting Alpine binary: %s\n", pathname);
        
        // Get current working directory for absolute paths
        char cwd[1024];
        if (getcwd(cwd, sizeof(cwd)) == NULL) {
            return real_execve(pathname, argv, envp);
        }
        
        // Set up Alpine dynamic linker path
        char alpine_ld[2048];
        snprintf(alpine_ld, sizeof(alpine_ld), "%s/.local/alpine/lib/ld-musl-x86_64.so.1", cwd);
        
        // Check if Alpine dynamic linker exists
        if (access(alpine_ld, X_OK) != 0) {
            fprintf(stderr, "⚠️  Alpine dynamic linker not found, falling back\n");
            return real_execve(pathname, argv, envp);
        }
        
        // Create new argv array with Alpine dynamic linker
        int argc = 0;
        while (argv[argc]) argc++;  // Count arguments
        
        char **new_argv = malloc((argc + 2) * sizeof(char*));
        if (!new_argv) {
            return real_execve(pathname, argv, envp);
        }
        
        new_argv[0] = alpine_ld;
        new_argv[1] = (char*)pathname;
        for (int i = 1; i <= argc; i++) {
            new_argv[i + 1] = argv[i];
        }
        
        fprintf(stderr, "✅ Redirecting to: %s %s\n", alpine_ld, pathname);
        
        // Execute with Alpine dynamic linker
        int result = real_execve(alpine_ld, new_argv, envp);
        
        free(new_argv);
        return result;
    }
    
    // For non-Alpine binaries, use normal execve
    return real_execve(pathname, argv, envp);
}

// Also intercept execv and execvp for completeness
int execv(const char *pathname, char *const argv[]) {
    return execve(pathname, argv, environ);
}

int execvp(const char *file, char *const argv[]) {
    // For execvp, we need to find the full path first
    // This is a simplified version - in practice, we'd need to search PATH
    return execve(file, argv, environ);
}