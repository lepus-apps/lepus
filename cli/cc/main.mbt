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
#cfg(platform="windows")
fn get_compile_args() -> (String, Array[String]) {
  ("cl.exe", [".mooncakes/lepus-apps/webview/lib/webview.lib"])
}

///|
#cfg(not(platform="windows"))
fn get_compile_args() -> (String, Array[String]) {
  (
    "cc",
    [
      "-L.mooncakes/lepus-apps/webview/lib", "-lwebview", "-Wl,-rpath,.mooncakes/lepus-apps/webview/lib",
    ],
  )
}
