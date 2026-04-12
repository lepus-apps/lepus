///|
enum SystemTarget {
  Darwin_arm64 = 1
  Darwin_x86_64 = 2
  Linux_arm64 = 3
  Linux_x86_64 = 4
  Windows_arm64 = 5
  Windows_x86_64 = 6
}

// ///|
// impl Show for SystemTarget with output(self, logger) {
//   logger.write_string(
//     match self {
//       Darwin_arm64 => "darwin_arm64"
//       Darwin_x86_64 => "darwin_x86_64"
//       Linux_arm64 => "linux_arm64"
//       Linux_x86_64 => "linux_x86_64"
//       Windows_arm64 => "windows_arm64"
//       Windows_x86_64 => "windows_x86_64"
//     },
//   )
// }

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
extern "C" fn detect_target() -> SystemTarget = "lepus_cc_detect_target"

///|
fn windows_link_args() -> Array[String] {
  [
    "-luser32", "-lshell32", "-lshlwapi", "-lversion", "-lole32", "-loleaut32", "-luuid",
    "-lcomdlg32", "-lcomctl32", "-lgdi32", "-ladvapi32", "-lws2_32", "-lkernel32",
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
        .map(p => p.to_string())
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
  let (stdout_r, stdout_w) = @pipe.pipe()
  defer stdout_r.close()
  let exit_code = @process.run(program, args, stdout=stdout_w) catch { _ => 1 }
  stdout_w.close()
  (exit_code, stdout_r.read_all().text())
}

///|
fn select_windows_compiler(target : SystemTarget) -> (String, Array[String]) {
  match @sys.get_env_var("CXX") {
    Some(cxx) => (cxx, [])
    None =>
      match @sys.get_env_var("CC") {
        Some(cc) => (cc, [])
        None =>
          match target {
            Windows_arm64 => ("zig", ["c++", "-target", "aarch64-windows-gnu"])
            _ => ("zig", ["c++", "-target", "x86_64-windows-gnu"])
          }
      }
  }
}

///|
async fn target_toolchain(
  target : SystemTarget,
) -> (String, Array[String], Array[String]) {
  match target {
    Darwin_arm64 | Darwin_x86_64 =>
      (
        "cc",
        [],
        ["-lc++", "-lobjc", "-framework", "Cocoa", "-framework", "WebKit"],
      )
    Linux_arm64 | Linux_x86_64 => ("cc", [], linux_link_args())
    Windows_arm64 | Windows_x86_64 => {
      let (compiler, prefix_args) = select_windows_compiler(target)
      (compiler, prefix_args, windows_link_args())
    }
  }
}

///|
async fn get_compile_args() -> (String, Array[String]) {
  let (compiler, prefix_args, link_args) = target_toolchain(detect_target())
  (compiler, [..prefix_args, ..link_args])
}
