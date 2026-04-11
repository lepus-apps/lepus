#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "moonbit.h"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

#if defined(__APPLE__)
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

static char g_last_error[256] = "";

static void set_error(const char *msg) {
  snprintf(g_last_error, sizeof(g_last_error), "%s", msg ? msg : "");
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_haptics_last_error_message(void) {
  int32_t len = (int32_t)strlen(g_last_error);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  if (len > 0) memcpy(out, g_last_error, (size_t)len);
  return out;
}

MOONBIT_FFI_EXPORT int32_t lp_haptics_pulse(int32_t intensity) {
  set_error("");
  (void)intensity;
#if defined(_WIN32)
  MessageBeep(MB_OK);
  return 0;
#elif defined(__APPLE__)
  pid_t pid = fork();
  if (pid < 0) {
    set_error("fork failed");
    return -1;
  }
  if (pid == 0) {
    execlp("osascript", "osascript", "-e", "beep", (char *)NULL);
    _exit(127);
  }
  int status = 0;
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    set_error("beep failed");
    return -1;
  }
  return 0;
#elif defined(__linux__)
  fprintf(stdout, "\a");
  fflush(stdout);
  return 0;
#else
  set_error("platform not supported");
  return -1;
#endif
}
