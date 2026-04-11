#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dlfcn.h>

#include "moonbit.h"

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

#if defined(__linux__) || defined(__APPLE__)
#include <sys/wait.h>
#include <unistd.h>
#endif

#if defined(__APPLE__)
typedef const void *CFTypeRef;
typedef const void *CFStringRef;
typedef const void *CFURLRef;
typedef const void *CFAllocatorRef;
typedef double CFTimeInterval;
typedef int32_t CFOptionFlags;
typedef int32_t SInt32;

typedef CFStringRef (*mb_cf_string_create_with_cstr_t)(
  CFAllocatorRef alloc,
  const char *cStr,
  uint32_t encoding
);
typedef void (*mb_cf_release_t)(CFTypeRef cf);
typedef SInt32 (*mb_cf_user_notification_display_alert_t)(
  CFTimeInterval timeout,
  CFOptionFlags flags,
  CFURLRef iconURL,
  CFURLRef soundURL,
  CFURLRef localizationURL,
  CFStringRef alertHeader,
  CFStringRef alertMessage,
  CFStringRef defaultButtonTitle,
  CFStringRef alternateButtonTitle,
  CFStringRef otherButtonTitle,
  CFOptionFlags *responseFlags
);

static const uint32_t MB_KCFSTRING_ENCODING_UTF8 = 0x08000100U;
static const CFOptionFlags MB_KCFUSERNOTIFICATION_STOP_ALERT_LEVEL = 0;
static const CFOptionFlags MB_KCFUSERNOTIFICATION_NOTE_ALERT_LEVEL = 1;
static const CFOptionFlags MB_KCFUSERNOTIFICATION_CAUTION_ALERT_LEVEL = 2;

typedef struct {
  void *handle;
  mb_cf_string_create_with_cstr_t cf_string_create_with_cstr;
  mb_cf_release_t cf_release;
  mb_cf_user_notification_display_alert_t cf_user_notification_display_alert;
  const CFAllocatorRef *kcf_allocator_default_ptr;
} mb_cf_api_t;

static int moonbit_dialog_load_cf_api(mb_cf_api_t *api) {
  if (!api) return 0;
  memset(api, 0, sizeof(*api));
  api->handle = dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY);
  if (!api->handle) return 0;

  api->cf_string_create_with_cstr = (mb_cf_string_create_with_cstr_t)dlsym(api->handle, "CFStringCreateWithCString");
  api->cf_release = (mb_cf_release_t)dlsym(api->handle, "CFRelease");
  api->cf_user_notification_display_alert =
    (mb_cf_user_notification_display_alert_t)dlsym(api->handle, "CFUserNotificationDisplayAlert");
  api->kcf_allocator_default_ptr = (const CFAllocatorRef *)dlsym(api->handle, "kCFAllocatorDefault");

  if (!api->cf_string_create_with_cstr || !api->cf_release ||
      !api->cf_user_notification_display_alert || !api->kcf_allocator_default_ptr) {
    dlclose(api->handle);
    memset(api, 0, sizeof(*api));
    return 0;
  }
  return 1;
}

static int moonbit_dialog_cf_alert(
  const char *title,
  const char *message,
  const char *default_button,
  const char *alternate_button,
  CFOptionFlags level_flags,
  int *accepted
) {
  mb_cf_api_t api;
  if (!moonbit_dialog_load_cf_api(&api)) {
    return -2;
  }

  CFAllocatorRef alloc = *(api.kcf_allocator_default_ptr);
  CFStringRef cf_title = api.cf_string_create_with_cstr(alloc, title ? title : "", MB_KCFSTRING_ENCODING_UTF8);
  CFStringRef cf_message = api.cf_string_create_with_cstr(alloc, message ? message : "", MB_KCFSTRING_ENCODING_UTF8);
  CFStringRef cf_default = api.cf_string_create_with_cstr(alloc, default_button ? default_button : "OK", MB_KCFSTRING_ENCODING_UTF8);
  CFStringRef cf_alternate = NULL;
  if (alternate_button) {
    cf_alternate = api.cf_string_create_with_cstr(alloc, alternate_button, MB_KCFSTRING_ENCODING_UTF8);
  }

  if (!cf_title || !cf_message || !cf_default || (alternate_button && !cf_alternate)) {
    if (cf_title) api.cf_release(cf_title);
    if (cf_message) api.cf_release(cf_message);
    if (cf_default) api.cf_release(cf_default);
    if (cf_alternate) api.cf_release(cf_alternate);
    dlclose(api.handle);
    return -3;
  }

  CFOptionFlags response = 0;
  SInt32 rc = api.cf_user_notification_display_alert(
    0.0,
    level_flags,
    NULL,
    NULL,
    NULL,
    cf_title,
    cf_message,
    cf_default,
    cf_alternate,
    NULL,
    &response
  );

  api.cf_release(cf_title);
  api.cf_release(cf_message);
  api.cf_release(cf_default);
  if (cf_alternate) api.cf_release(cf_alternate);
  dlclose(api.handle);

  if (rc != 0) return -1;
  if (accepted) {
    *accepted = (response == 0) ? 1 : 0;
  }
  return 0;
}
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

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_dialog_last_error_message(void) {
  return to_bytes(g_last_error);
}

MOONBIT_FFI_EXPORT int32_t lp_dialog_alert(const char *title, const char *message, int32_t level) {
  set_error("");
  if (!title) title = "Dialog";
  if (!message) message = "";
#if defined(_WIN32)
  UINT icon = MB_ICONINFORMATION;
  if (level == 1) icon = MB_ICONWARNING;
  if (level == 2) icon = MB_ICONERROR;
  int wt = MultiByteToWideChar(CP_UTF8, 0, title, -1, NULL, 0);
  int wm = MultiByteToWideChar(CP_UTF8, 0, message, -1, NULL, 0);
  if (wt <= 0 || wm <= 0) {
    set_error("utf8 decode failed");
    return -1;
  }
  wchar_t *wtitle = (wchar_t *)malloc((size_t)wt * sizeof(wchar_t));
  wchar_t *wmsg = (wchar_t *)malloc((size_t)wm * sizeof(wchar_t));
  if (!wtitle || !wmsg) {
    free(wtitle); free(wmsg);
    set_error("out of memory");
    return -1;
  }
  MultiByteToWideChar(CP_UTF8, 0, title, -1, wtitle, wt);
  MultiByteToWideChar(CP_UTF8, 0, message, -1, wmsg, wm);
  MessageBoxW(NULL, wmsg, wtitle, MB_OK | icon | MB_SYSTEMMODAL);
  free(wtitle); free(wmsg);
  return 0;
#elif defined(__APPLE__)
  int accepted = 0;
  CFOptionFlags flags = MB_KCFUSERNOTIFICATION_NOTE_ALERT_LEVEL;
  if (level == 1) flags = MB_KCFUSERNOTIFICATION_CAUTION_ALERT_LEVEL;
  if (level == 2) flags = MB_KCFUSERNOTIFICATION_STOP_ALERT_LEVEL;
  int rc = moonbit_dialog_cf_alert(title, message, "OK", NULL, flags, &accepted);
  if (rc == -2) {
    set_error("CoreFoundation load failed");
    return -1;
  }
  if (rc == -3) {
    set_error("CoreFoundation string allocation failed");
    return -1;
  }
  if (rc != 0) {
    set_error("CoreFoundation alert failed");
    return -1;
  }
  return 0;
#elif defined(__linux__)
  pid_t pid = fork();
  if (pid < 0) { set_error("fork failed"); return -1; }
  if (pid == 0) {
    execlp("zenity", "zenity", "--info", "--title", title, "--text", message, (char *)NULL);
    _exit(127);
  }
  int status = 0;
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status)) {
    set_error("zenity failed");
    return -1;
  }
  if (WEXITSTATUS(status) != 0) {
    set_error("zenity exited with non-zero status");
    return -1;
  }
  return 0;
#else
  set_error("platform not supported");
  return -1;
#endif
}

MOONBIT_FFI_EXPORT int32_t lp_dialog_confirm(const char *title, const char *message, int32_t default_ok) {
  set_error("");
  if (!title) title = "Confirm";
  if (!message) message = "";
#if defined(_WIN32)
  int wt = MultiByteToWideChar(CP_UTF8, 0, title, -1, NULL, 0);
  int wm = MultiByteToWideChar(CP_UTF8, 0, message, -1, NULL, 0);
  if (wt <= 0 || wm <= 0) { set_error("utf8 decode failed"); return -1; }
  wchar_t *wtitle = (wchar_t *)malloc((size_t)wt * sizeof(wchar_t));
  wchar_t *wmsg = (wchar_t *)malloc((size_t)wm * sizeof(wchar_t));
  if (!wtitle || !wmsg) { free(wtitle); free(wmsg); set_error("out of memory"); return -1; }
  MultiByteToWideChar(CP_UTF8, 0, title, -1, wtitle, wt);
  MultiByteToWideChar(CP_UTF8, 0, message, -1, wmsg, wm);
  UINT flags = MB_YESNO | MB_ICONQUESTION | MB_SYSTEMMODAL | (default_ok ? MB_DEFBUTTON1 : MB_DEFBUTTON2);
  int ret = MessageBoxW(NULL, wmsg, wtitle, flags);
  free(wtitle); free(wmsg);
  return ret == IDYES ? 1 : 0;
#elif defined(__APPLE__)
  int accepted = 0;
  int rc = 0;
  if (default_ok) {
    rc = moonbit_dialog_cf_alert(
      title,
      message,
      "OK",
      "Cancel",
      MB_KCFUSERNOTIFICATION_NOTE_ALERT_LEVEL,
      &accepted
    );
    if (rc == 0) return accepted;
  } else {
    rc = moonbit_dialog_cf_alert(
      title,
      message,
      "Cancel",
      "OK",
      MB_KCFUSERNOTIFICATION_NOTE_ALERT_LEVEL,
      &accepted
    );
    if (rc == 0) return accepted ? 0 : 1;
  }
  if (rc == -2) { set_error("CoreFoundation load failed"); return -1; }
  if (rc == -3) { set_error("CoreFoundation string allocation failed"); return -1; }
  set_error("CoreFoundation confirm failed");
  return -1;
#elif defined(__linux__)
  pid_t pid = fork();
  if (pid < 0) { set_error("fork failed"); return -1; }
  if (pid == 0) {
    execlp("zenity", "zenity", "--question", "--title", title, "--text", message, (char *)NULL);
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
