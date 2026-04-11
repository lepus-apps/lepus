#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "moonbit.h"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

#if defined(__linux__) || defined(__APPLE__)
#include <sys/wait.h>
#include <unistd.h>
#endif

static char g_last_error[512] = "";

static void set_error(const char *msg) {
  snprintf(g_last_error, sizeof(g_last_error), "%s", msg ? msg : "");
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_biometric_last_error_message(void) {
  int32_t len = (int32_t)strlen(g_last_error);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  if (len > 0) memcpy(out, g_last_error, (size_t)len);
  return out;
}

MOONBIT_FFI_EXPORT int32_t lp_biometric_available(void) {
#if defined(_WIN32) || defined(__APPLE__) || defined(__linux__)
  return 1;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT int32_t lp_biometric_authenticate(const char *reason) {
  set_error("");
  if (!reason) reason = "Authenticate";
#if defined(_WIN32)
  int wt = MultiByteToWideChar(CP_UTF8, 0, "Biometric/Auth", -1, NULL, 0);
  int wm = MultiByteToWideChar(CP_UTF8, 0, reason, -1, NULL, 0);
  if (wt <= 0 || wm <= 0) { set_error("utf8 decode failed"); return -1; }
  wchar_t title[64];
  wchar_t message[512];
  MultiByteToWideChar(CP_UTF8, 0, "Biometric/Auth", -1, title, 64);
  MultiByteToWideChar(CP_UTF8, 0, reason, -1, message, 512);
  int ret = MessageBoxW(NULL, message, title, MB_OKCANCEL | MB_ICONQUESTION | MB_SYSTEMMODAL);
  return ret == IDOK ? 1 : 0;
#elif defined(__APPLE__)
  pid_t pid = fork();
  if (pid < 0) { set_error("fork failed"); return -1; }
  if (pid == 0) {
    execlp("osascript", "osascript", "-e",
           "on run argv\n"
           "set r to display dialog (item 1 of argv) with title \"Biometric/Auth\" buttons {\"Cancel\", \"OK\"} default button \"OK\"\n"
           "if button returned of r is \"OK\" then return \"1\" else return \"0\"\n"
           "end run",
           reason, (char *)NULL);
    _exit(127);
  }
  int status = 0;
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status)) { set_error("osascript failed"); return -1; }
  return WEXITSTATUS(status) == 0 ? 1 : 0;
#elif defined(__linux__)
  pid_t pid = fork();
  if (pid < 0) { set_error("fork failed"); return -1; }
  if (pid == 0) {
    execlp("zenity", "zenity", "--question", "--title", "Biometric/Auth", "--text", reason, (char *)NULL);
    _exit(127);
  }
  int status = 0;
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status)) { set_error("zenity failed"); return -1; }
  return WEXITSTATUS(status) == 0 ? 1 : 0;
#else
  set_error("platform not supported");
  return -1;
#endif
}
