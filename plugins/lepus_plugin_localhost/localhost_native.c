#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "moonbit.h"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
static PROCESS_INFORMATION g_proc = {0};
#else
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
static pid_t g_pid = -1;
#endif

static char g_last_error[512] = "";

static void set_error(const char *msg) {
  snprintf(g_last_error, sizeof(g_last_error), "%s", msg ? msg : "");
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_localhost_last_error_message(void) {
  int32_t len = (int32_t)strlen(g_last_error);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  if (len > 0) memcpy(out, g_last_error, (size_t)len);
  return out;
}

MOONBIT_FFI_EXPORT int32_t lp_localhost_status(void) {
#if defined(_WIN32)
  if (!g_proc.hProcess) return 0;
  DWORD code = 0;
  if (!GetExitCodeProcess(g_proc.hProcess, &code)) return 0;
  return code == STILL_ACTIVE ? 1 : 0;
#else
  if (g_pid <= 0) return 0;
  if (kill(g_pid, 0) == 0) return 1;
  return 0;
#endif
}

MOONBIT_FFI_EXPORT int32_t lp_localhost_start(const char *root, int32_t port) {
  set_error("");
  if (!root || root[0] == '\0') {
    set_error("root path is empty");
    return -1;
  }
  if (port <= 0 || port > 65535) {
    set_error("invalid port");
    return -1;
  }
  if (lp_localhost_status() == 1) {
    set_error("server already running");
    return -1;
  }
#if defined(_WIN32)
  char cmdline[1024];
  snprintf(cmdline, sizeof(cmdline),
           "cmd /C cd /d \"%s\" && python -m http.server %d --bind 127.0.0.1",
           root, (int)port);
  STARTUPINFOA si;
  ZeroMemory(&si, sizeof(si));
  si.cb = sizeof(si);
  ZeroMemory(&g_proc, sizeof(g_proc));
  if (!CreateProcessA(NULL, cmdline, NULL, NULL, FALSE, CREATE_NEW_PROCESS_GROUP, NULL, NULL, &si, &g_proc)) {
    set_error("CreateProcess failed");
    return -1;
  }
  return (int32_t)g_proc.dwProcessId;
#else
  pid_t pid = fork();
  if (pid < 0) {
    set_error("fork failed");
    return -1;
  }
  if (pid == 0) {
    if (chdir(root) != 0) _exit(127);
    char p[16];
    snprintf(p, sizeof(p), "%d", (int)port);
    execlp("python3", "python3", "-m", "http.server", p, "--bind", "127.0.0.1", (char *)NULL);
    execlp("python", "python", "-m", "http.server", p, "--bind", "127.0.0.1", (char *)NULL);
    _exit(127);
  }
  g_pid = pid;
  return (int32_t)pid;
#endif
}

MOONBIT_FFI_EXPORT int32_t lp_localhost_stop(void) {
  set_error("");
#if defined(_WIN32)
  if (!g_proc.hProcess) return 0;
  if (!TerminateProcess(g_proc.hProcess, 0)) {
    set_error("TerminateProcess failed");
    return -1;
  }
  CloseHandle(g_proc.hProcess);
  CloseHandle(g_proc.hThread);
  ZeroMemory(&g_proc, sizeof(g_proc));
  return 0;
#else
  if (g_pid <= 0) return 0;
  if (kill(g_pid, SIGTERM) != 0) {
    set_error("kill failed");
    return -1;
  }
  int status = 0;
  waitpid(g_pid, &status, 0);
  g_pid = -1;
  return 0;
#endif
}
