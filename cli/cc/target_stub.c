#include <moonbit.h>
#include <stdint.h>
#include <string.h>

// 0: unknown
// 1: darwin_arm64
// 2: darwin_x86_64
// 3: linux_arm64
// 4: linux_x86_64
// 5: windows_arm64
// 6: windows_x86_64
MOONBIT_FFI_EXPORT
int32_t lepus_cc_detect_target(void) {
#if defined(__APPLE__) && defined(__aarch64__)
  return 1;
#elif defined(__APPLE__) && defined(__x86_64__)
  return 2;
#elif defined(__linux__) && defined(__aarch64__)
  return 3;
#elif defined(__linux__) && defined(__x86_64__)
  return 4;
#elif defined(_WIN32) && defined(_M_ARM64)
  return 5;
#elif defined(_WIN32) && defined(_M_X64)
  return 6;
#else
  return 0;
#endif
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t lepus_cc_source_root(void) {
  const char *src = __FILE__;
  int32_t len = (int32_t)strlen(src);
  while (len > 0 && src[len - 1] != '/' && src[len - 1] != '\\') {
    len--;
  }
  if (len > 0) {
    len--;
  }
  while (len > 0 && src[len - 1] != '/' && src[len - 1] != '\\') {
    len--;
  }
  if (len > 0) {
    len--;
  }
  while (len > 0 && src[len - 1] != '/' && src[len - 1] != '\\') {
    len--;
  }
  if (len > 0 && (src[len - 1] == '/' || src[len - 1] == '\\')) {
    len--;
  }

  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  memcpy(out, src, len);
  return out;
}
