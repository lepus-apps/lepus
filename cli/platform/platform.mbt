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
/// Detect the current platform using environment variables.
///
/// Checks in order:
///   1. LEPUS_PLATFORM (explicit override, e.g. "macos", "linux", "windows")
///   2. OSTYPE (bash/zsh convention)
///   3. OS (Windows CMD convention, Windows_NT)
pub fn detect_platform() -> Platform {
  match @env.get_env_var("LEPUS_PLATFORM") {
    Some(p) if !p.is_empty() => Platform::parse(p.to_lower())
    _ => detect_platform_from_env()
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
/// Detect the CPU architecture using environment variables.
///
/// Checks in order:
///   1. LEPUS_ARCH (explicit override, e.g. "arm64", "x86_64")
///   2. HOSTTYPE (bash/zsh convention)
///   3. PROCESSOR_ARCHITECTURE (Windows CMD convention)
///   4. PROCESSOR_ARCHITEW6432 (Windows CMD WoW64 convention)
pub fn detect_arch() -> Arch {
  match @env.get_env_var("LEPUS_ARCH") {
    Some(a) if !a.is_empty() => Arch::parse(a.to_lower())
    _ => detect_arch_from_env()
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
/// Detect the combined system target using environment variables.
///
/// Checks in order:
///   1. LEPUS_TARGET (explicit override, e.g. "darwin_arm64")
///   2. OSTYPE / OS + HOSTTYPE / PROCESSOR_ARCHITECTURE
pub fn detect_target() -> Target {
  guard @env.get_env_var("LEPUS_TARGET") is Some([_, ..] as t) else {
    return Target(detect_platform(), detect_arch())
  }
  Target::parse(t.to_lower())
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
