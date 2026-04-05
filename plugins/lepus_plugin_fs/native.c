#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <direct.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <windows.h>
#define strdup _strdup
#else
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#endif

#include "moonbit.h"

static char g_last_error[512] = "";

static void fs_clear_error(void) { g_last_error[0] = '\0'; }

static void fs_set_error(const char *message) {
  if (message == NULL) {
    fs_clear_error();
    return;
  }
  strncpy(g_last_error, message, sizeof(g_last_error) - 1);
  g_last_error[sizeof(g_last_error) - 1] = '\0';
}

static void fs_set_errno_error(const char *prefix) {
  char buffer[512];
  snprintf(
      buffer, sizeof(buffer), "%s: %s", prefix == NULL ? "error" : prefix,
      strerror(errno));
  fs_set_error(buffer);
}

#ifdef _WIN32
static void fs_set_windows_error(const char *prefix) {
  DWORD code = GetLastError();
  LPSTR message = NULL;
  DWORD flags = FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
                FORMAT_MESSAGE_IGNORE_INSERTS;
  DWORD length = FormatMessageA(
      flags, NULL, code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      (LPSTR)&message, 0, NULL);
  if (length == 0 || message == NULL) {
    char buffer[512];
    snprintf(
        buffer, sizeof(buffer), "%s: Windows error %lu",
        prefix == NULL ? "error" : prefix, (unsigned long)code);
    fs_set_error(buffer);
    return;
  }
  {
    char buffer[512];
    while (length > 0 &&
           (message[length - 1] == '\r' || message[length - 1] == '\n')) {
      message[length - 1] = '\0';
      length -= 1;
    }
    snprintf(
        buffer, sizeof(buffer), "%s: %s", prefix == NULL ? "error" : prefix,
        message);
    fs_set_error(buffer);
  }
  LocalFree(message);
}
#endif

static moonbit_bytes_t fs_copy_string(const char *value) {
  if (value == NULL || value[0] == '\0') {
    moonbit_bytes_t bytes = moonbit_make_bytes_raw(1);
    bytes[0] = '\0';
    return bytes;
  }
  {
    size_t length = strlen(value) + 1;
    moonbit_bytes_t bytes = moonbit_make_bytes_raw((int32_t)length);
    memcpy(bytes, value, length);
    return bytes;
  }
}

static int fs_is_separator(char ch) { return ch == '/' || ch == '\\'; }

static int fs_path_exists(const char *path) {
  struct stat st;
  return stat(path, &st) == 0;
}

static int fs_path_is_dir(const char *path) {
  struct stat st;
  if (stat(path, &st) != 0) {
    return 0;
  }
#ifdef _WIN32
  return (st.st_mode & _S_IFDIR) != 0;
#else
  return S_ISDIR(st.st_mode);
#endif
}

static int fs_is_root_prefix(const char *path, size_t length) {
  if (length == 1 && fs_is_separator(path[0])) {
    return 1;
  }
  if (length == 2 && isalpha((unsigned char)path[0]) && path[1] == ':') {
    return 1;
  }
  if (length == 3 && isalpha((unsigned char)path[0]) && path[1] == ':' &&
      fs_is_separator(path[2])) {
    return 1;
  }
  return 0;
}

static int fs_mkdir_single(const char *path) {
  if (path == NULL || path[0] == '\0') {
    fs_set_error("mkdir: empty path");
    return -1;
  }
  if (fs_path_is_dir(path)) {
    return 0;
  }
#ifdef _WIN32
  if (_mkdir(path) == 0) {
    return 0;
  }
#else
  if (mkdir(path, 0755) == 0) {
    return 0;
  }
#endif
  if (errno == EEXIST && fs_path_is_dir(path)) {
    return 0;
  }
  fs_set_errno_error("mkdir");
  return -1;
}

static int fs_mkdir_recursive(char *path) {
  size_t length = strlen(path);
  size_t start = 0;
  size_t i;

  if (length == 0) {
    fs_set_error("mkdir: empty path");
    return -1;
  }
  if (fs_is_separator(path[0])) {
    start = 1;
  } else if (length >= 2 && isalpha((unsigned char)path[0]) &&
             path[1] == ':') {
    start = 2;
    if (length >= 3 && fs_is_separator(path[2])) {
      start = 3;
    }
  }

  for (i = start; path[i] != '\0'; i++) {
    if (!fs_is_separator(path[i])) {
      continue;
    }
    {
      char saved = path[i];
      path[i] = '\0';
      if (path[0] != '\0' && !fs_is_root_prefix(path, strlen(path))) {
        if (fs_mkdir_single(path) != 0) {
          path[i] = saved;
          return -1;
        }
      }
      path[i] = saved;
      while (fs_is_separator(path[i + 1])) {
        i += 1;
      }
    }
  }

  if (fs_is_root_prefix(path, strlen(path))) {
    return 0;
  }
  return fs_mkdir_single(path);
}

static int fs_remove_single(const char *path) {
  if (!fs_path_exists(path)) {
    fs_set_error("remove: path does not exist");
    return -1;
  }
  if (fs_path_is_dir(path)) {
#ifdef _WIN32
    if (_rmdir(path) == 0) {
      return 0;
    }
#else
    if (rmdir(path) == 0) {
      return 0;
    }
#endif
    fs_set_errno_error("remove directory");
    return -1;
  }
  if (remove(path) == 0) {
    return 0;
  }
  fs_set_errno_error("remove file");
  return -1;
}

#ifdef _WIN32
static int fs_remove_recursive(const char *path) {
  DWORD attributes = GetFileAttributesA(path);
  size_t path_length;
  if (attributes == INVALID_FILE_ATTRIBUTES) {
    fs_set_windows_error("remove");
    return -1;
  }
  if ((attributes & FILE_ATTRIBUTE_DIRECTORY) == 0) {
    if (DeleteFileA(path)) {
      return 0;
    }
    fs_set_windows_error("remove file");
    return -1;
  }

  path_length = strlen(path);
  {
    size_t pattern_length = path_length + 3;
    char *pattern = (char *)malloc(pattern_length);
    WIN32_FIND_DATAA entry;
    HANDLE handle;

    if (pattern == NULL) {
      fs_set_error("remove: out of memory");
      return -1;
    }
    snprintf(pattern, pattern_length, "%s\\*", path);
    handle = FindFirstFileA(pattern, &entry);
    free(pattern);

    if (handle == INVALID_HANDLE_VALUE) {
      DWORD code = GetLastError();
      if (code != ERROR_FILE_NOT_FOUND && code != ERROR_PATH_NOT_FOUND) {
        fs_set_windows_error("remove directory");
        return -1;
      }
    } else {
      do {
        const char *name = entry.cFileName;
        if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
          continue;
        }
        {
          size_t child_length = path_length + 1 + strlen(name) + 1;
          char *child = (char *)malloc(child_length);
          if (child == NULL) {
            FindClose(handle);
            fs_set_error("remove: out of memory");
            return -1;
          }
          snprintf(child, child_length, "%s\\%s", path, name);
          if (fs_remove_recursive(child) != 0) {
            free(child);
            FindClose(handle);
            return -1;
          }
          free(child);
        }
      } while (FindNextFileA(handle, &entry) != 0);
      FindClose(handle);
    }
  }

  if (RemoveDirectoryA(path)) {
    return 0;
  }
  fs_set_windows_error("remove directory");
  return -1;
}
#else
static int fs_remove_recursive(const char *path) {
  struct stat st;
  if (stat(path, &st) != 0) {
    fs_set_errno_error("remove");
    return -1;
  }
  if (!S_ISDIR(st.st_mode)) {
    if (remove(path) == 0) {
      return 0;
    }
    fs_set_errno_error("remove file");
    return -1;
  }
  {
    DIR *dir = opendir(path);
    struct dirent *entry;
    if (dir == NULL) {
      fs_set_errno_error("remove directory");
      return -1;
    }
    while ((entry = readdir(dir)) != NULL) {
      const char *name = entry->d_name;
      if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
        continue;
      }
      {
        size_t child_length = strlen(path) + 1 + strlen(name) + 1;
        char *child = (char *)malloc(child_length);
        if (child == NULL) {
          closedir(dir);
          fs_set_error("remove: out of memory");
          return -1;
        }
        snprintf(child, child_length, "%s/%s", path, name);
        if (fs_remove_recursive(child) != 0) {
          free(child);
          closedir(dir);
          return -1;
        }
        free(child);
      }
    }
    closedir(dir);
  }
  if (rmdir(path) == 0) {
    return 0;
  }
  fs_set_errno_error("remove directory");
  return -1;
}
#endif

MOONBIT_FFI_EXPORT int lepus_fs_exists(moonbit_bytes_t path) {
  if (path == NULL || path[0] == '\0') {
    return 0;
  }
  return fs_path_exists((const char *)path);
}

MOONBIT_FFI_EXPORT int lepus_fs_is_dir(moonbit_bytes_t path) {
  if (path == NULL || path[0] == '\0') {
    return 0;
  }
  return fs_path_is_dir((const char *)path);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lepus_fs_read_text(moonbit_bytes_t path) {
  FILE *file;
  long length;
  size_t read_size;
  moonbit_bytes_t bytes;

  fs_clear_error();
  if (path == NULL || path[0] == '\0') {
    fs_set_error("read_text: empty path");
    return fs_copy_string("");
  }

  file = fopen((const char *)path, "rb");
  if (file == NULL) {
    fs_set_errno_error("read_text");
    return fs_copy_string("");
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    fs_set_errno_error("read_text");
    return fs_copy_string("");
  }
  length = ftell(file);
  if (length < 0) {
    fclose(file);
    fs_set_errno_error("read_text");
    return fs_copy_string("");
  }
  if (length > INT32_MAX - 1) {
    fclose(file);
    fs_set_error("read_text: file is too large");
    return fs_copy_string("");
  }
  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    fs_set_errno_error("read_text");
    return fs_copy_string("");
  }

  bytes = moonbit_make_bytes_raw((int32_t)length + 1);
  read_size = fread(bytes, 1, (size_t)length, file);
  if (fclose(file) != 0) {
    fs_set_errno_error("read_text");
    bytes[0] = '\0';
    return bytes;
  }
  if (read_size != (size_t)length) {
    fs_set_errno_error("read_text");
    bytes[0] = '\0';
    return bytes;
  }
  bytes[length] = '\0';
  return bytes;
}

MOONBIT_FFI_EXPORT int lepus_fs_write_text(
    moonbit_bytes_t path, moonbit_bytes_t content) {
  FILE *file;
  size_t length;

  fs_clear_error();
  if (path == NULL || path[0] == '\0') {
    fs_set_error("write_text: empty path");
    return -1;
  }
  file = fopen((const char *)path, "wb");
  if (file == NULL) {
    fs_set_errno_error("write_text");
    return -1;
  }
  length = strlen((const char *)content);
  if (length > 0 && fwrite(content, 1, length, file) != length) {
    fclose(file);
    fs_set_errno_error("write_text");
    return -1;
  }
  if (fclose(file) != 0) {
    fs_set_errno_error("write_text");
    return -1;
  }
  return 0;
}

MOONBIT_FFI_EXPORT int lepus_fs_mkdir(moonbit_bytes_t path, int recursive) {
  char *buffer;

  fs_clear_error();
  if (path == NULL || path[0] == '\0') {
    fs_set_error("mkdir: empty path");
    return -1;
  }
  if (!recursive) {
    return fs_mkdir_single((const char *)path);
  }
  buffer = strdup((const char *)path);
  if (buffer == NULL) {
    fs_set_error("mkdir: out of memory");
    return -1;
  }
  {
    int result = fs_mkdir_recursive(buffer);
    free(buffer);
    return result;
  }
}

MOONBIT_FFI_EXPORT int lepus_fs_remove(moonbit_bytes_t path, int recursive) {
  fs_clear_error();
  if (path == NULL || path[0] == '\0') {
    fs_set_error("remove: empty path");
    return -1;
  }
  if (recursive) {
    return fs_remove_recursive((const char *)path);
  }
  return fs_remove_single((const char *)path);
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lepus_fs_last_error(void) {
  return fs_copy_string(g_last_error);
}
