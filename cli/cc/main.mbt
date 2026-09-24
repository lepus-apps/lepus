///|
/// proxy of c compiler for cross platform
async fn main {
  let args = @env.args()[1:]
  let (compiler, compiler_args) = get_compile_args()
  @sys.exit(
    @process.run(compiler, [..args, ..compiler_args]) catch {
      err => {
        println("Failed to execute compiler: \{err}")
        1
      }
    },
  )
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
            _ if target is @platform.WindowsArm64 =>
              ("zig", ["c++", "-target", "aarch64-windows-gnu"])
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
    _ if target is @platform.DarwinArm64 || target is @platform.DarwinX86_64 =>
      (
        "cc",
        [],
        ["-lc++", "-lobjc", "-framework", "Cocoa", "-framework", "WebKit"],
      )
    _ if target is @platform.LinuxArm64 || target is @platform.LinuxX86_64 =>
      ("cc", [], linux_link_args())
    _ if target is @platform.WindowsArm64 || target is @platform.WindowsX86_64 => {
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
