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
extern "C" fn detect_target() -> Int = "lepus_cc_detect_target"

///|
extern "C" fn source_root_bytes() -> Bytes = "lepus_cc_source_root"

///|
fn target_dir() -> String? {
  match detect_target() {
    1 => Some("darwin_arm64")
    2 => Some("darwin_x86_64")
    3 => Some("linux_arm64")
    4 => Some("linux_x86_64")
    5 => Some("windows_arm64")
    6 => Some("windows_x86_64")
    _ => None
  }
}

///|
fn static_link_args(target : String, static_lib : String) -> Array[String] {
  match target {
    "darwin_arm64" =>
      [
        static_lib, "-lc++", "-lobjc", "-framework", "Cocoa", "-framework", "WebKit",
      ]
    "darwin_x86_64" =>
      [
        static_lib, "-lc++", "-lobjc", "-framework", "Cocoa", "-framework", "WebKit",
      ]
    "linux_arm64" => [static_lib, "-lstdc++", "-ldl", "-lpthread"]
    "linux_x86_64" => [static_lib, "-lstdc++", "-ldl", "-lpthread"]
    _ => [static_lib]
  }
}

///|
fn source_root() -> String {
  @utf8.decode_lossy(source_root_bytes())
}

///|
async fn file_exists(path : String) -> Bool {
  (@process.run("sh", ["-c", "test -f \"$1\"", "_", path]) catch { _ => 1 }) ==
  0
}

///|
#cfg(platform="windows")
async fn get_compile_args() -> (String, Array[String]) {
  ("cl.exe", [".mooncakes/lepus-apps/webview/lib/webview.lib"])
}

///|
#cfg(not(platform="windows"))
async fn get_compile_args() -> (String, Array[String]) {
  match target_dir() {
    Some(target) => {
      let static_lib = "\{source_root()}/cli/cc/\{target}/libwebview.a"
      if file_exists(static_lib) {
        return ("cc", static_link_args(target, static_lib))
      }

      let relative_static_lib = "lepus/cli/cc/\{target}/libwebview.a"
      if file_exists(relative_static_lib) {
        return ("cc", static_link_args(target, relative_static_lib))
      }
    }
    None => ()
  }

  match @sys.get_env_var("LEPUS_WEBVIEW_STATIC_LIB") {
    Some(static_lib) =>
      if file_exists(static_lib) {
        return (
          "cc",
          [
            static_lib, "-lc++", "-lobjc", "-framework", "Cocoa", "-framework", "WebKit",
          ],
        )
      }
    None => ()
  }

  (
    "cc",
    [
      "-L.mooncakes/lepus-apps/webview/lib", "-lwebview", "-Wl,-rpath,.mooncakes/lepus-apps/webview/lib",
      "-Wl,-rpath,@executable_path/../../.mooncakes/lepus-apps/webview/lib", "-Wl,-rpath,@loader_path/../../.mooncakes/lepus-apps/webview/lib",
    ],
  )
}
