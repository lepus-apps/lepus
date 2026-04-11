#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#ifdef _MSC_VER
#pragma comment(lib, "shell32.lib")
#endif
#endif

#if defined(__linux__) || defined(__APPLE__)
#include <sys/wait.h>
#include <unistd.h>
#endif

#if defined(_MSC_VER)
#define LP_THREAD_LOCAL __declspec(thread)
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#define LP_THREAD_LOCAL _Thread_local
#else
#define LP_THREAD_LOCAL
#endif

static LP_THREAD_LOCAL char lp_last_error_message[512] = "";

static void lp_set_error(const char *message) {
  if (message == NULL) {
    lp_last_error_message[0] = '\0';
    return;
  }
  snprintf(lp_last_error_message, sizeof(lp_last_error_message), "%s", message);
}

MOONBIT_FFI_EXPORT int32_t lp_opener_platform_supported(void) {
#if defined(_WIN32) || defined(__APPLE__) || defined(__linux__)
  return 1;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_opener_last_error_message(void) {
  int32_t len = (int32_t)strlen(lp_last_error_message);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  if (len > 0) {
    memcpy(out, lp_last_error_message, (size_t)len);
  }
  return out;
}

MOONBIT_FFI_EXPORT int32_t lp_opener_open(const char *target) {
  lp_set_error(NULL);
  if (target == NULL || target[0] == '\0') {
    lp_set_error("target is empty");
    return 1;
  }

#if defined(_WIN32)
  HINSTANCE rc = ShellExecuteA(NULL, "open", target, NULL, NULL, SW_SHOWNORMAL);
  if ((intptr_t)rc <= 32) {
    lp_set_error("ShellExecute failed");
    return 1;
  }
  return 0;
#elif defined(__APPLE__)
  pid_t pid = fork();
  if (pid < 0) {
    lp_set_error("fork failed");
    return 1;
  }
  if (pid == 0) {
    execlp("open", "open", target, (char *)NULL);
    _exit(127);
  }
  int status = 0;
  if (waitpid(pid, &status, 0) < 0) {
    lp_set_error("waitpid failed");
    return 1;
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    lp_set_error("open command failed");
    return 1;
  }
  return 0;
#elif defined(__linux__)
  pid_t pid = fork();
  if (pid < 0) {
    lp_set_error("fork failed");
    return 1;
  }
  if (pid == 0) {
    execlp("xdg-open", "xdg-open", target, (char *)NULL);
    _exit(127);
  }
  int status = 0;
  if (waitpid(pid, &status, 0) < 0) {
    lp_set_error("waitpid failed");
    return 1;
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    lp_set_error("xdg-open command failed");
    return 1;
  }
  return 0;
#else
  lp_set_error("platform not supported");
  return 1;
#endif
}
