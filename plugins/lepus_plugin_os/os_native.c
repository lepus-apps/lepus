#include <stdint.h>
#include <string.h>

#include "moonbit.h"

static moonbit_bytes_t lp_make_bytes(const char *s) {
  int32_t len = (int32_t)strlen(s);
  moonbit_bytes_t out = moonbit_make_bytes(len, 0);
  memcpy(out, s, (size_t)len);
  return out;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_os_name(void) {
#if defined(_WIN32)
  return lp_make_bytes("windows");
#elif defined(__APPLE__)
  return lp_make_bytes("macos");
#elif defined(__linux__)
  return lp_make_bytes("linux");
#else
  return lp_make_bytes("unknown");
#endif
}

MOONBIT_FFI_EXPORT moonbit_bytes_t lp_os_arch(void) {
#if defined(__x86_64__) || defined(_M_X64)
  return lp_make_bytes("x86_64");
#elif defined(__aarch64__) || defined(_M_ARM64)
  return lp_make_bytes("arm64");
#elif defined(__i386__) || defined(_M_IX86)
  return lp_make_bytes("x86");
#else
  return lp_make_bytes("unknown");
#endif
}
