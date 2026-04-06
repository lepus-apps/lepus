///|
/// proxy of c compiler for cross platform
async fn main {
  let raw_args : Array[String] = @env.args()[1:].to_array()
  let (compiler, args, compiler_args) = get_compile_args(raw_args)
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
#cfg(platform="windows")
fn get_compile_args(
  raw_args : Array[String],
) -> (String, Array[String], Array[String]) {
  (
    "cl.exe",
    normalize_windows_args(raw_args),
    [".mooncakes/lepus-apps/webview/lib/webview.lib"],
  )
}

///|
#cfg(not(platform="windows"))
fn get_compile_args(
  raw_args : Array[String],
) -> (String, Array[String], Array[String]) {
  (
    "cc",
    raw_args,
    [
      "-L.mooncakes/lepus-apps/webview/lib", "-lwebview", "-Wl,-rpath,.mooncakes/lepus-apps/webview/lib",
    ],
  )
}
