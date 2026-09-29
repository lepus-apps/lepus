// Platform detection via C preprocessor — reliable at build time, unlike
// OSTYPE/HOSTTYPE which shell variables do not export to child processes.
//
// Integer return values MUST stay in sync with the MoonBit enums in
// platform.mbt (Platform / Arch / Target).

#include <moonbit.h>
#include <stdint.h>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

// Platform: 0 Unknown, 1 OpenHarmony, 2 IOS, 3 Android,
//           4 MacOS, 5 Linux, 6 Windows, 7 FreeBSD
static int lepus_detect_os_c(void) {
#if defined(__OHOS__)
  return 1;
#elif defined(__ANDROID__)
  return 3;
#elif defined(__APPLE__)
  #if TARGET_OS_IOS
  return 2;
  #elif TARGET_OS_MAC
  return 4;
  #else
  return 4;
  #endif
#elif defined(__linux__)
  return 5;
#elif defined(_WIN32)
  return 6;
#elif defined(__FreeBSD__)
  return 7;
#else
  return 0;
#endif
}

// Arch: 0 Arm64, 1 X86_64
static int lepus_detect_arch_c(void) {
#if defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64)
  return 0;
#elif defined(__x86_64__) || defined(__amd64__) || defined(_M_X64)
  return 1;
#else
  return 1;
#endif
}

// Target: 0 Unknown, 1 Darwin_Arm64, 2 Darwin_X86_64,
//         3 Linux_Arm64, 4 Linux_X86_64,
//         5 Windows_Arm64, 6 Windows_X86_64
static int lepus_detect_target_c(void) {
  int os = lepus_detect_os_c();
  int arch = lepus_detect_arch_c();
  switch (os) {
    case 4: // MacOS -> Darwin
      return arch == 0 ? 1 : 2;
    case 5: // Linux
      return arch == 0 ? 3 : 4;
    case 6: // Windows
      return arch == 0 ? 5 : 6;
    default:
      return 0;
  }
}

MOONBIT_FFI_EXPORT int32_t lepus_platform_detect_os(void) {
  return (int32_t)lepus_detect_os_c();
}

MOONBIT_FFI_EXPORT int32_t lepus_platform_detect_arch(void) {
  return (int32_t)lepus_detect_arch_c();
}

MOONBIT_FFI_EXPORT int32_t lepus_platform_detect_target(void) {
  return (int32_t)lepus_detect_target_c();
}
