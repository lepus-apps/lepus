///|
/// proxy of c compiler for cross platform
async fn main {
  let args = @env.args()[1:]
  let (compiler, compiler_args) = get_compile_args()
  let exit_code = @process.run(compiler, [..args, ..compiler_args]) catch {
    err => {
      println("Failed to execute compiler: \{err}")
      1
    }
  }
  if exit_code == 0 {
    strip_linked_output(args)
  }
  @sys.exit(exit_code)
}

///|
/// Drops the Mach-O symbol table from the freshly linked executable.
///
/// A release build still carries ~4k symbols plus a ~180 KB string table in
/// `__LINKEDIT` that the process never reads at runtime; removing them takes
/// roughly 20% off the binary. Neither `moon build --strip` (debug info only)
/// nor `ld -s` (obsolete, no longer does anything) removes that table, so it is
/// done here as a post-link step.
///
/// Skipped for non-Darwin targets and for compile-only invocations. Only release
/// artifacts are touched; `strip` rewrites the embedded ad-hoc signature itself,
/// so no separate re-signing step is needed.
///
/// Set `LEPUS_SKIP_STRIP=1` to keep symbol names, e.g. so panic backtraces stay
/// symbolicated.
async fn strip_linked_output(args : ArrayView[String]) -> Unit {
  let enabled = match @platform.detect_target() {
    Darwin_Arm64 | Darwin_X86_64 => @env.get_env_var("LEPUS_SKIP_STRIP") is None
    _ => false
  }
  // `-c`/`-S`/`-E` produce no executable, so there is nothing to strip.
  let compile_only = args.contains("-c") ||
    args.contains("-S") ||
    args.contains("-E")
  if enabled && !compile_only {
    match output_path(args) {
      Some(path) =>
        if is_release_output(path) {
          ignore(@process.run("strip", [path]) catch { _ => 0 })
        }
      None => ()
    }
  }
}

///|
/// Tells a release artifact from a debug one.
///
/// `moon build` does not pass `-g` to the link step, so the output location is
/// the reliable signal: release builds land in `_build/<target>/release/...`
/// while debug builds land in `_build/<target>/debug/...`. Should that layout
/// ever change this fails safe — no strip, just a larger binary.
fn is_release_output(path : String) -> Bool {
  path.contains("/release/")
}

///|
/// Extracts the `-o` destination so the post-link `strip` knows what to target,
/// accepting both the separated (`-o path`) and joined (`-opath`) spellings.
fn output_path(args : ArrayView[String]) -> String? {
  let mut index = 0
  while index < args.length() {
    let arg = args[index]
    if arg == "-o" {
      return if index + 1 < args.length() {
        Some(args[index + 1])
      } else {
        None
      }
    }
    if arg is [.. "-o", .. path] {
      return Some(path.to_owned())
    }
    index = index + 1
  }
  None
}

///|
fn windows_link_args() -> Array[String] {
  [
    "-mwindows", "-luser32", "-lshell32", "-lshlwapi", "-lversion", "-lole32", "-loleaut32",
    "-luuid", "-lcomdlg32", "-lcomctl32", "-lgdi32", "-ladvapi32", "-lws2_32", "-lkernel32",
  ]
}

///|
async fn linux_pkg_config_args() -> Array[String] {
  let candidates = [
    ["--libs", "webkit2gtk-4.1", "gtk+-3.0"],
    ["--libs", "webkit2gtk-4.0", "gtk+-3.0"],
  ]
  for args in candidates {
    let (exit_code, output) = run_capture("pkg-config", args)
    if exit_code == 0 {
      let libs = output
        .trim()
        .split(" ")
        .filter(part => part != "")
        .map(p => p.to_owned())
        .to_array()
      if libs.length() > 0 {
        return libs
      }
    }
  }
  [
    "-lwebkit2gtk-4.1", "-ljavascriptcoregtk-4.1", "-lgtk-3", "-lgdk-3", "-lsoup-3.0",
    "-lgobject-2.0", "-lglib-2.0", "-lgio-2.0", "-lstdc++", "-ldl", "-lpthread",
  ]
}

///|
async fn linux_link_args() -> Array[String] {
  let pkg = linux_pkg_config_args()
  let args = ["-lstdc++", "-ldl", "-lpthread"]
  for arg in pkg {
    if !args.contains(arg) {
      args.push(arg)
    }
  }
  args
}

///|
async fn run_capture(program : String, args : Array[String]) -> (Int, String) {
  let (stdout_r, stdout_w) = @process.read_from_process(shared=true) catch {
    _ => return (1, "")
  }
  defer stdout_r.close()
  let exit_code = @process.run(program, args, stdout=stdout_w) catch { _ => 1 }
  (exit_code, stdout_r.read_all().text())
}

///|
fn select_windows_compiler(
  target : @platform.Target,
) -> (String, Array[String]) {
  match @env.get_env_var("CXX") {
    Some(cxx) => (cxx, [])
    None =>
      match @env.get_env_var("CC") {
        Some(cc) => (cc, [])
        None =>
          match target {
            Windows_Arm64 => ("zig", ["c++", "-target", "aarch64-windows-gnu"])
            _ => ("zig", ["c++", "-target", "x86_64-windows-gnu"])
          }
      }
  }
}

///|
async fn target_toolchain(
  target : @platform.Target,
) -> (String, Array[String], Array[String]) {
  match target {
    Darwin_Arm64 | Darwin_X86_64 =>
      (
        "cc",
        [],
        ["-lc++", "-lobjc", "-framework", "Cocoa", "-framework", "WebKit"],
      )
    Linux_Arm64 | Linux_X86_64 => ("cc", [], linux_link_args())
    Windows_Arm64 | Windows_X86_64 => {
      let (compiler, prefix_args) = select_windows_compiler(target)
      (compiler, prefix_args, windows_link_args())
    }
    _ => ("cc", [], [])
  }
}

///|
async fn get_compile_args() -> (String, Array[String]) {
  let (compiler, prefix_args, link_args) = target_toolchain(
    @platform.detect_target(),
  )
  (compiler, [..prefix_args, ..link_args])
}
