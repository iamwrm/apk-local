#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>

// Original function pointers
static int (*orig_execve)(const char *pathname, char *const argv[], char *const envp[]) = NULL;
static int (*orig_execvp)(const char *file, char *const argv[]) = NULL;

// Initialize original function pointers
void __attribute__((constructor)) init(void) {
    orig_execve = dlsym(RTLD_NEXT, "execve");
    orig_execvp = dlsym(RTLD_NEXT, "execvp");
    
    if (getenv("ALPINE_INTERCEPTOR_DEBUG")) {
        printf("[ALPINE-INTERCEPTOR] Loaded successfully\n");
        printf("[ALPINE-INTERCEPTOR] execve at %p\n", orig_execve);
        printf("[ALPINE-INTERCEPTOR] execvp at %p\n", orig_execvp);
    }
}

// Check if this is an Alpine binary
int is_alpine_binary(const char *pathname) {
    if (!pathname) return 0;
    
    // Check for Alpine-specific paths
    if (strstr(pathname, "/.local/alpine/") ||
        strstr(pathname, "/alpine/") ||
        strstr(pathname, "x86_64-alpine-linux-musl")) {
        return 1;
    }
    
    return 0;
}

// Check if this is a GCC subprocess we care about
int is_gcc_subprocess(const char *pathname) {
    if (!pathname) return 0;
    
    char *basename = strrchr(pathname, '/');
    if (!basename) basename = (char*)pathname;
    else basename++;
    
    return (strcmp(basename, "cc1") == 0 ||
            strcmp(basename, "collect2") == 0 ||
            strcmp(basename, "ld") == 0 ||
            strcmp(basename, "as") == 0);
}

// Execute command in Alpine container
int execute_in_alpine_container(const char *pathname, char *const argv[], char *const envp[]) {
    if (getenv("ALPINE_INTERCEPTOR_DEBUG")) {
        printf("[CONTAINER] Intercepted Alpine binary: %s\n", pathname);
        for (int i = 0; argv[i]; i++) {
            printf("[CONTAINER] argv[%d] = %s\n", i, argv[i]);
        }
    }
    
    // Get current working directory
    char cwd[4096];
    if (!getcwd(cwd, sizeof(cwd))) {
        perror("getcwd");
        return -1;
    }
    
    // Build container command
    char cmd[8192];
    int cmd_len = snprintf(cmd, sizeof(cmd),
        "docker run --rm -i --network=none "
        "-v '%s:/workspace' -w /workspace "
        "-v '%s:%s:ro' "
        "alpine:latest %s",
        cwd, pathname, pathname, pathname);
    
    // Add arguments
    for (int i = 1; argv[i] && cmd_len < sizeof(cmd) - 100; i++) {
        // Simple argument escaping (not production-ready)
        if (strchr(argv[i], ' ') || strchr(argv[i], '\'') || strchr(argv[i], '"')) {
            cmd_len += snprintf(cmd + cmd_len, sizeof(cmd) - cmd_len, " '%s'", argv[i]);
        } else {
            cmd_len += snprintf(cmd + cmd_len, sizeof(cmd) - cmd_len, " %s", argv[i]);
        }
    }
    
    if (getenv("ALPINE_INTERCEPTOR_DEBUG")) {
        printf("[CONTAINER] Executing: %s\n", cmd);
    }
    
    // Execute the command
    int result = system(cmd);
    
    if (getenv("ALPINE_INTERCEPTOR_DEBUG")) {
        printf("[CONTAINER] Command result: %d\n", result);
    }
    
    return result;
}

// Intercept execve calls
int execve(const char *pathname, char *const argv[], char *const envp[]) {
    // Only intercept Alpine GCC-related binaries
    if (is_alpine_binary(pathname) && is_gcc_subprocess(pathname)) {
        if (getenv("ALPINE_INTERCEPTOR_DEBUG")) {
            printf("[INTERCEPTED] Alpine GCC subprocess: %s\n", pathname);
        }
        return execute_in_alpine_container(pathname, argv, envp);
    }
    
    // For everything else, use original execve
    return orig_execve(pathname, argv, envp);
}

// Intercept execvp calls (some programs use this instead)
int execvp(const char *file, char *const argv[]) {
    // Convert to full path if needed for our detection
    char full_path[4096];
    
    // If file contains '/', it's already a path
    if (strchr(file, '/')) {
        strncpy(full_path, file, sizeof(full_path) - 1);
        full_path[sizeof(full_path) - 1] = '\0';
    } else {
        // Search in PATH (simplified)
        char *path_env = getenv("PATH");
        if (path_env) {
            char *path_copy = strdup(path_env);
            char *dir = strtok(path_copy, ":");
            
            while (dir) {
                snprintf(full_path, sizeof(full_path), "%s/%s", dir, file);
                if (access(full_path, X_OK) == 0) {
                    break;
                }
                dir = strtok(NULL, ":");
            }
            
            free(path_copy);
            if (!dir) {
                // Not found, use original
                return orig_execvp(file, argv);
            }
        } else {
            // No PATH, use original
            return orig_execvp(file, argv);
        }
    }
    
    // Check if this is an Alpine binary we should intercept
    if (is_alpine_binary(full_path) && is_gcc_subprocess(full_path)) {
        if (getenv("ALPINE_INTERCEPTOR_DEBUG")) {
            printf("[INTERCEPTED] Alpine GCC subprocess (via execvp): %s\n", full_path);
        }
        
        // Convert execvp to execve call
        extern char **environ;
        return execute_in_alpine_container(full_path, argv, environ);
    }
    
    // For everything else, use original execvp
    return orig_execvp(file, argv);
}