#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

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

static moonbit_bytes_t to_bytes(const char *s) {
  int32_t len = (int32_t)strlen(s);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  if (len > 0) memcpy(out, s, (size_t)len);
  return out;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_notify_last_error_message(void) {
  return to_bytes(g_last_error);
}

MOONBIT_FFI_EXPORT int32_t lp_notify_send(const char *title, const char *body) {
  set_error("");
  if (!title) title = "";
  if (!body) body = "";

#if defined(_WIN32)
  int wtitle_len = MultiByteToWideChar(CP_UTF8, 0, title, -1, NULL, 0);
  int wbody_len = MultiByteToWideChar(CP_UTF8, 0, body, -1, NULL, 0);
  if (wtitle_len <= 0 || wbody_len <= 0) {
    set_error("utf8 decode failed");
    return 1;
  }
  wchar_t *wtitle = (wchar_t *)malloc(sizeof(wchar_t) * (size_t)wtitle_len);
  wchar_t *wbody = (wchar_t *)malloc(sizeof(wchar_t) * (size_t)wbody_len);
  if (!wtitle || !wbody) {
    free(wtitle);
    free(wbody);
    set_error("out of memory");
    return 1;
  }
  MultiByteToWideChar(CP_UTF8, 0, title, -1, wtitle, wtitle_len);
  MultiByteToWideChar(CP_UTF8, 0, body, -1, wbody, wbody_len);
  MessageBoxW(NULL, wbody, wtitle, MB_OK | MB_ICONINFORMATION | MB_SYSTEMMODAL);
  free(wtitle);
  free(wbody);
  return 0;
#elif defined(__APPLE__)
  pid_t pid = fork();
  if (pid < 0) {
    set_error("fork failed");
    return 1;
  }
  if (pid == 0) {
    execlp("osascript", "osascript", "-e",
           "on run argv\n"
           "display notification (item 2 of argv) with title (item 1 of argv)\n"
           "end run",
           title, body, (char *)NULL);
    _exit(127);
  }
  int status = 0;
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    set_error("osascript notification failed");
    return 1;
  }
  return 0;
#elif defined(__linux__)
  pid_t pid = fork();
  if (pid < 0) {
    set_error("fork failed");
    return 1;
  }
  if (pid == 0) {
    execlp("notify-send", "notify-send", title, body, (char *)NULL);
    _exit(127);
  }
  int status = 0;
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    set_error("notify-send failed");
    return 1;
  }
  return 0;
#else
  set_error("platform not supported");
  return 1;
#endif
}
