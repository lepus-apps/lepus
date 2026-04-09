#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <stdio.h>

#include "moonbit.h"

static moonbit_bytes_t lepus_copy_string(const char *value) {
  if (value == NULL || value[0] == '\0') {
    moonbit_bytes_t bytes = moonbit_make_bytes_raw(0);
    return bytes;
  }
  size_t len = strlen(value);
  moonbit_bytes_t bytes = moonbit_make_bytes_raw((int32_t)len);
  memcpy(bytes, value, len);
  return bytes;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lepus_env_get(moonbit_bytes_t name) {
  return lepus_copy_string(getenv((const char *)name));
}

MOONBIT_FFI_EXPORT int lepus_command_exists(moonbit_bytes_t command) {
  char buffer[1024];
  snprintf(buffer, sizeof(buffer), "command -v '%s' >/dev/null 2>&1", (const char *)command);
  return system(buffer) == 0;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lepus_current_dir(void) {
  char buffer[PATH_MAX];
  if (getcwd(buffer, sizeof(buffer)) == NULL) {
    return lepus_copy_string("");
  }
  return lepus_copy_string(buffer);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lepus_platform_name(void) {
#if defined(__APPLE__)
  return lepus_copy_string("macos");
#elif defined(__linux__)
  return lepus_copy_string("linux");
#elif defined(_WIN32)
  return lepus_copy_string("windows");
#else
  return lepus_copy_string("unknown");
#endif
}

MOONBIT_FFI_EXPORT void lepus_exit(int code) {
  exit(code);
}