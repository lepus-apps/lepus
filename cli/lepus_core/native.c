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
    moonbit_bytes_t bytes = moonbit_make_bytes_raw(1);
    bytes[0] = '\0';
    return bytes;
  }
  size_t len = strlen(value) + 1;
  moonbit_bytes_t bytes = moonbit_make_bytes_raw((int32_t)len);
  memcpy(bytes, value, len);
  return bytes;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lepus_env_get(moonbit_bytes_t name) {
  return lepus_copy_string(getenv((const char *)name));
}

MOONBIT_FFI_EXPORT int lepus_file_exists(moonbit_bytes_t path) {
  struct stat st;
  return stat((const char *)path, &st) == 0;
}

MOONBIT_FFI_EXPORT int lepus_directory_exists(moonbit_bytes_t path) {
  struct stat st;
  if (stat((const char *)path, &st) != 0) {
    return 0;
  }
  return S_ISDIR(st.st_mode);
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

MOONBIT_FFI_EXPORT moonbit_bytes_t lepus_realpath(moonbit_bytes_t path) {
  char resolved[PATH_MAX];
  if (realpath((const char *)path, resolved) == NULL) {
    return lepus_copy_string("");
  }
  return lepus_copy_string(resolved);
}

MOONBIT_FFI_EXPORT int lepus_mkdir_p(moonbit_bytes_t path) {
  char *buffer = strdup((const char *)path);
  char *cursor = NULL;

  if (buffer == NULL) {
    return -1;
  }

  for (cursor = buffer + 1; *cursor != '\0'; cursor++) {
    if (*cursor == '/') {
      *cursor = '\0';
      if (mkdir(buffer, 0755) != 0 && errno != EEXIST) {
        free(buffer);
        return -1;
      }
      *cursor = '/';
    }
  }

  if (mkdir(buffer, 0755) != 0 && errno != EEXIST) {
    free(buffer);
    return -1;
  }

  free(buffer);
  return 0;
}

MOONBIT_FFI_EXPORT int lepus_write_text_file(
  moonbit_bytes_t path,
  moonbit_bytes_t content
) {
  FILE *file = fopen((const char *)path, "wb");
  size_t length = strlen((const char *)content);

  if (file == NULL) {
    return -1;
  }

  if (length > 0 && fwrite(content, 1, length, file) != length) {
    fclose(file);
    return -1;
  }

  if (fclose(file) != 0) {
    return -1;
  }

  return 0;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lepus_read_text_file(moonbit_bytes_t path) {
  FILE *file = fopen((const char *)path, "rb");
  long length;
  size_t read_size;
  moonbit_bytes_t bytes;

  if (file == NULL) {
    return lepus_copy_string("");
  }

  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return lepus_copy_string("");
  }

  length = ftell(file);
  if (length < 0) {
    fclose(file);
    return lepus_copy_string("");
  }

  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return lepus_copy_string("");
  }

  bytes = moonbit_make_bytes_raw((int32_t)length + 1);
  read_size = fread(bytes, 1, (size_t)length, file);
  fclose(file);

  if (read_size != (size_t)length) {
    bytes[0] = '\0';
    return bytes;
  }

  bytes[length] = '\0';
  return bytes;
}
