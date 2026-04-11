#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "moonbit.h"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
static HANDLE g_lock_handle = NULL;
#else
#include <fcntl.h>
#include <unistd.h>
static int g_lock_fd = -1;
#endif

static char g_last_error[256] = "";

static void set_error(const char *msg) {
  snprintf(g_last_error, sizeof(g_last_error), "%s", msg ? msg : "");
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_single_instance_last_error_message(void) {
  int32_t len = (int32_t)strlen(g_last_error);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  if (len > 0) memcpy(out, g_last_error, (size_t)len);
  return out;
}

MOONBIT_FFI_EXPORT int32_t lp_single_instance_acquire(const char *app_id) {
  set_error("");
  if (!app_id || app_id[0] == '\0') {
    set_error("app_id is empty");
    return 1;
  }
#if defined(_WIN32)
  if (g_lock_handle) return 0;
  char name[200];
  snprintf(name, sizeof(name), "Global\\LepusSingleInstance_%s", app_id);
  g_lock_handle = CreateMutexA(NULL, TRUE, name);
  if (!g_lock_handle) {
    set_error("CreateMutex failed");
    return 1;
  }
  if (GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(g_lock_handle);
    g_lock_handle = NULL;
    set_error("already running");
    return 2;
  }
  return 0;
#else
  if (g_lock_fd >= 0) return 0;
  char path[256];
  snprintf(path, sizeof(path), "/tmp/lepus-single-instance-%s.lock", app_id);
  g_lock_fd = open(path, O_CREAT | O_EXCL | O_RDWR, 0600);
  if (g_lock_fd < 0) {
    set_error("already running or cannot create lock");
    return 2;
  }
  return 0;
#endif
}

MOONBIT_FFI_EXPORT void lp_single_instance_release(void) {
#if defined(_WIN32)
  if (g_lock_handle) {
    ReleaseMutex(g_lock_handle);
    CloseHandle(g_lock_handle);
    g_lock_handle = NULL;
  }
#else
  if (g_lock_fd >= 0) {
    close(g_lock_fd);
    g_lock_fd = -1;
  }
#endif
}
