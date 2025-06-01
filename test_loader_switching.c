#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

// LD_PRELOAD library to demonstrate timing limitations
static int (*orig_execve)(const char *pathname, char *const argv[], char *const envp[]) = NULL;

void __attribute__((constructor)) init(void) {
    // Use write() to avoid printf complications during library loading
    const char *msg = "[LD_PRELOAD] Library loaded - this proves the process started successfully!\n";
    write(STDERR_FILENO, msg, strlen(msg));
    
    orig_execve = dlsym(RTLD_NEXT, "execve");
}

int execve(const char *pathname, char *const argv[], char *const envp[]) {
    const char *prefix = "[LD_PRELOAD] execve() intercepted for: ";
    write(STDERR_FILENO, prefix, strlen(prefix));
    write(STDERR_FILENO, pathname, strlen(pathname));
    write(STDERR_FILENO, "\n", 1);
    
    // This demonstrates we can intercept execve calls
    // But by this point, the current process already started with its fixed loader
    if (pathname && (strstr(pathname, "musl") || strstr(pathname, "alpine"))) {
        const char *warning = "[LD_PRELOAD] This appears to be a musl binary\n";
        write(STDERR_FILENO, warning, strlen(warning));
        const char *explanation = "[LD_PRELOAD] But the kernel already chose the loader from PT_INTERP!\n";
        write(STDERR_FILENO, explanation, strlen(explanation));
    }
    
    return orig_execve(pathname, argv, envp);
}