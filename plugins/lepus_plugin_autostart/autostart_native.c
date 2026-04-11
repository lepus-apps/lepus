#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "moonbit.h"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
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

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_autostart_last_error_message(void) {
  return to_bytes(g_last_error);
}

#if defined(_WIN32)
static LONG open_run_key(HKEY *out, REGSAM access) {
  return RegOpenKeyExA(HKEY_CURRENT_USER, "Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0, access, out);
}
#endif

MOONBIT_FFI_EXPORT int32_t lp_autostart_status(const char *app_id) {
  set_error("");
  if (!app_id || app_id[0] == '\0') {
    set_error("app_id is empty");
    return -1;
  }
#if defined(_WIN32)
  HKEY key = NULL;
  if (open_run_key(&key, KEY_QUERY_VALUE) != ERROR_SUCCESS) {
    set_error("open Run registry key failed");
    return -1;
  }
  LONG rc = RegQueryValueExA(key, app_id, NULL, NULL, NULL, NULL);
  RegCloseKey(key);
  return rc == ERROR_SUCCESS ? 1 : 0;
#elif defined(__APPLE__)
  const char *home = getenv("HOME");
  if (!home) { set_error("HOME missing"); return -1; }
  char path[1024];
  snprintf(path, sizeof(path), "%s/Library/LaunchAgents/%s.plist", home, app_id);
  FILE *f = fopen(path, "r");
  if (!f) return 0;
  fclose(f);
  return 1;
#elif defined(__linux__)
  const char *home = getenv("HOME");
  if (!home) { set_error("HOME missing"); return -1; }
  char path[1024];
  snprintf(path, sizeof(path), "%s/.config/autostart/%s.desktop", home, app_id);
  FILE *f = fopen(path, "r");
  if (!f) return 0;
  fclose(f);
  return 1;
#else
  set_error("platform not supported");
  return -1;
#endif
}

MOONBIT_FFI_EXPORT int32_t lp_autostart_enable(const char *app_id, const char *exec_path, const char *args) {
  set_error("");
  if (!app_id || !exec_path || app_id[0] == '\0' || exec_path[0] == '\0') {
    set_error("invalid app_id or exec_path");
    return -1;
  }
  if (!args) args = "";
#if defined(_WIN32)
  HKEY key = NULL;
  if (RegCreateKeyExA(HKEY_CURRENT_USER, "Software\\Microsoft\\Windows\\CurrentVersion\\Run", 0, NULL, 0, KEY_SET_VALUE, NULL, &key, NULL) != ERROR_SUCCESS) {
    set_error("create/open Run registry key failed");
    return -1;
  }
  char cmd[1024];
  if (args[0] != '\0') snprintf(cmd, sizeof(cmd), "\"%s\" %s", exec_path, args);
  else snprintf(cmd, sizeof(cmd), "\"%s\"", exec_path);
  LONG rc = RegSetValueExA(key, app_id, 0, REG_SZ, (const BYTE *)cmd, (DWORD)(strlen(cmd) + 1));
  RegCloseKey(key);
  if (rc != ERROR_SUCCESS) {
    set_error("set Run registry value failed");
    return -1;
  }
  return 0;
#elif defined(__APPLE__)
  const char *home = getenv("HOME");
  if (!home) { set_error("HOME missing"); return -1; }
  char dir[1024];
  snprintf(dir, sizeof(dir), "%s/Library/LaunchAgents", home);
  char mkdir_cmd[1200];
  snprintf(mkdir_cmd, sizeof(mkdir_cmd), "mkdir -p \"%s\"", dir);
  if (system(mkdir_cmd) != 0) { set_error("create LaunchAgents dir failed"); return -1; }
  char path[1200];
  snprintf(path, sizeof(path), "%s/%s.plist", dir, app_id);
  FILE *f = fopen(path, "w");
  if (!f) { set_error("write plist failed"); return -1; }
  fprintf(f,
          "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
          "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
          "<plist version=\"1.0\"><dict>\n"
          "<key>Label</key><string>%s</string>\n"
          "<key>ProgramArguments</key><array><string>%s</string>%s%s</array>\n"
          "<key>RunAtLoad</key><true/>\n"
          "</dict></plist>\n",
          app_id, exec_path, args[0] ? "<string>" : "", args[0] ? args : "");
  fclose(f);
  return 0;
#elif defined(__linux__)
  const char *home = getenv("HOME");
  if (!home) { set_error("HOME missing"); return -1; }
  char dir[1024];
  snprintf(dir, sizeof(dir), "%s/.config/autostart", home);
  char mkdir_cmd[1200];
  snprintf(mkdir_cmd, sizeof(mkdir_cmd), "mkdir -p \"%s\"", dir);
  if (system(mkdir_cmd) != 0) { set_error("create autostart dir failed"); return -1; }
  char path[1200];
  snprintf(path, sizeof(path), "%s/%s.desktop", dir, app_id);
  FILE *f = fopen(path, "w");
  if (!f) { set_error("write desktop entry failed"); return -1; }
  if (args[0] != '\0')
    fprintf(f, "[Desktop Entry]\nType=Application\nName=%s\nExec=\"%s\" %s\nX-GNOME-Autostart-enabled=true\n", app_id, exec_path, args);
  else
    fprintf(f, "[Desktop Entry]\nType=Application\nName=%s\nExec=\"%s\"\nX-GNOME-Autostart-enabled=true\n", app_id, exec_path);
  fclose(f);
  return 0;
#else
  set_error("platform not supported");
  return -1;
#endif
}

MOONBIT_FFI_EXPORT int32_t lp_autostart_disable(const char *app_id) {
  set_error("");
  if (!app_id || app_id[0] == '\0') {
    set_error("app_id is empty");
    return -1;
  }
#if defined(_WIN32)
  HKEY key = NULL;
  if (open_run_key(&key, KEY_SET_VALUE) != ERROR_SUCCESS) {
    set_error("open Run registry key failed");
    return -1;
  }
  RegDeleteValueA(key, app_id);
  RegCloseKey(key);
  return 0;
#elif defined(__APPLE__)
  const char *home = getenv("HOME");
  if (!home) { set_error("HOME missing"); return -1; }
  char path[1024];
  snprintf(path, sizeof(path), "%s/Library/LaunchAgents/%s.plist", home, app_id);
  remove(path);
  return 0;
#elif defined(__linux__)
  const char *home = getenv("HOME");
  if (!home) { set_error("HOME missing"); return -1; }
  char path[1024];
  snprintf(path, sizeof(path), "%s/.config/autostart/%s.desktop", home, app_id);
  remove(path);
  return 0;
#else
  set_error("platform not supported");
  return -1;
#endif
}
