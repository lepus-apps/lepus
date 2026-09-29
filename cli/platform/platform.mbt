///|
/// The operating system platform.
pub enum Platform {
  OpenHarmony
  IOS
  Android
  MacOS
  Linux
  Windows
  Unknown
}

///|
pub fn Platform::to_string(self : Platform) -> String {
  match self {
    OpenHarmony => "openharmony"
    IOS => "ios"
    Android => "android"
    MacOS => "macos"
    Linux => "linux"
    Windows => "windows"
    Unknown => "unknown"
  }
}

///|
fn Platform::from_int(n : Int) -> Platform {
  match n {
    1 => OpenHarmony
    2 => IOS
    3 => Android
    4 => MacOS
    5 => Linux
    6 => Windows
    _ => Unknown
  }
}

///|
/// The CPU architecture.
pub enum Arch {
  Arm64
  X86_64
}

///|
pub extend Arch with Show::{to_string, output}

///|
pub impl Show for Arch with fn output(self, logger) {
  logger.write(
    match self {
      Arm64 => "arm64"
      X86_64 => "x86_64"
    },
  )
}

///|
fn Arch::from_int(n : Int) -> Arch {
  match n {
    0 => Arm64
    _ => X86_64
  }
}

///|
/// The combined system target (OS + architecture).
pub enum Target {
  Unknown
  Darwin_Arm64
  Darwin_X86_64
  Linux_Arm64
  Linux_X86_64
  Windows_Arm64
  Windows_X86_64
}

///|
pub fn Target::to_string(self : Target) -> String {
  match self {
    Unknown => "unknown"
    Darwin_Arm64 => "darwin_arm64"
    Darwin_X86_64 => "darwin_x86_64"
    Linux_Arm64 => "linux_arm64"
    Linux_X86_64 => "linux_x86_64"
    Windows_Arm64 => "windows_arm64"
    Windows_X86_64 => "windows_x86_64"
  }
}

///|
fn Target::from_int(n : Int) -> Target {
  match n {
    1 => Darwin_Arm64
    2 => Darwin_X86_64
    3 => Linux_Arm64
    4 => Linux_X86_64
    5 => Windows_Arm64
    6 => Windows_X86_64
    _ => Unknown
  }
}

///|
/// Native platform detection via the C preprocessor (`detect.c`).
/// Reliable at build time, unlike `OSTYPE`/`HOSTTYPE` which shell variables
/// do not export to child processes.
///
/// Return codes are kept in sync with `Platform::from_int` /
/// `Arch::from_int` / `Target::from_int`.
extern "C" fn native_detect_os() -> Int = "lepus_platform_detect_os"

///|
extern "C" fn native_detect_arch() -> Int = "lepus_platform_detect_arch"

///|
extern "C" fn native_detect_target() -> Int = "lepus_platform_detect_target"

///|
/// Detect the current platform.
///
/// Checks in order:
///   1. LEPUS_PLATFORM (explicit override, e.g. "macos", "linux", "windows")
///   2. native C detection (build-time preprocessor)
///   3. OSTYPE / OS (shell convention, may not be exported to children)
pub fn detect_platform() -> Platform {
  match @env.get_env_var("LEPUS_PLATFORM") {
    Some(p) if !p.is_empty() => Platform::parse(p.to_lower())
    _ =>
      match native_detect_os() {
        0 => detect_platform_from_env()
        n => Platform::from_int(n)
      }
  }
}

///|
fn Platform::parse(s : String) -> Platform {
  match s {
    "openharmony" | "ohos" => OpenHarmony
    "ios" => IOS
    "android" => Android
    "macos" | "darwin" => MacOS
    "linux" => Linux
    "windows" | "win32" | "cygwin" | "msys" => Windows
    _ => Unknown
  }
}

///|
fn detect_platform_from_env() -> Platform {
  let os_type = @env.get_env_var("OSTYPE")
  guard os_type is Some(os_type) else { return Unknown }

  match os_type {
    [.. "darwin", ..] => MacOS
    [.. "linux", ..] => Linux
    [.. "msys", ..] | [.. "cygwin", ..] | [.. "win32", ..] => Windows
    _ =>
      if @env.get_env_var("OS") is Some("Windows_NT") {
        Windows
      } else {
        Unknown
      }
  }
}

///|
/// Detect the CPU architecture.
///
/// Checks in order:
///   1. LEPUS_ARCH (explicit override, e.g. "arm64", "x86_64")
///   2. native C detection (build-time preprocessor)
///   3. HOSTTYPE / PROCESSOR_ARCHITECTURE (shell / Windows CMD convention)
pub fn detect_arch() -> Arch {
  match @env.get_env_var("LEPUS_ARCH") {
    Some(a) if !a.is_empty() => Arch::parse(a.to_lower())
    _ =>
      match native_detect_arch() {
        // native returns 0 for Arm64, 1 for X86_64; both are known, so only
        // fall back to env probes when the C layer reports the unknown slot.
        // (No unknown slot is currently emitted, but keep the guard for safety.)
        -1 => detect_arch_from_env()
        n => Arch::from_int(n)
      }
  }
}

///|
fn Arch::parse(s : String) -> Arch {
  match s {
    "arm64" | "aarch64" => Arm64
    "x86_64" | "amd64" => X86_64
    _ => X86_64
  }
}

///|
fn detect_arch_from_env() -> Arch {
  match @env.get_env_var("HOSTTYPE") {
    Some([.. "aarch64", ..] | [.. "arm64", ..]) => Arm64
    Some([.. "x86_64", ..] | [.. "amd64", ..]) => X86_64
    _ =>
      match
        @env.get_env_var("PROCESSOR_ARCHITECTURE").unwrap_or(
          @env.get_env_var("PROCESSOR_ARCHITEW6432").unwrap_or("AMD64"),
        ) {
        "ARM64" => Arm64
        _ => X86_64
      }
  }
}

///|
/// Detect the combined system target.
///
/// Checks in order:
///   1. LEPUS_TARGET (explicit override, e.g. "darwin_arm64")
///   2. native C detection (build-time preprocessor, combines OS + arch)
///   3. detect_platform() + detect_arch()
pub fn detect_target() -> Target {
  match @env.get_env_var("LEPUS_TARGET") {
    Some(t) if !t.is_empty() => Target::parse(t.to_lower())
    _ =>
      match native_detect_target() {
        0 => Target(detect_platform(), detect_arch())
        n => Target::from_int(n)
      }
  }
}

///|
fn Target::parse(s : String) -> Target {
  match s {
    "darwin_arm64" => Darwin_Arm64
    "darwin_x86_64" => Darwin_X86_64
    "linux_arm64" => Linux_Arm64
    "linux_x86_64" => Linux_X86_64
    "windows_arm64" => Windows_Arm64
    "windows_x86_64" => Windows_X86_64
    _ => Unknown
  }
}

///|
fn Target::Target(platform : Platform, arch : Arch) -> Target {
  match (platform, arch) {
    (MacOS, Arm64) => Darwin_Arm64
    (MacOS, X86_64) => Darwin_X86_64
    (Linux, Arm64) => Linux_Arm64
    (Linux, X86_64) => Linux_X86_64
    (Windows, Arm64) => Windows_Arm64
    (Windows, X86_64) => Windows_X86_64
    _ => Unknown
  }
}
