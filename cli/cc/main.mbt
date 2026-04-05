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
  // `moon test` passes GCC-style flags (`-o`, `-I`, `-g`, `-lm`) to this
  // proxy. With `CC=cl.exe`, those flags are ignored or misparsed by MSVC.
  // One visible effect is object files falling back to the current directory
  // (`*.obj` in repository root) instead of the expected `_build` path.
  // Convert supported flags to MSVC-style here so output paths stay stable.
  (
    "cl.exe",
    normalize_windows_args(raw_args),
    [".mooncakes/lepus-apps/webview/lib/webview.lib"],
  )
}

///|
#cfg(platform="windows")
fn normalize_windows_args(args : Array[String]) -> Array[String] {
  let converted : Array[String] = []
  for i = 0, compile_only = false; i < args.length(); {
    let arg = args[i]
    if arg == "-c" {
      converted.push("/c")
      continue i + 1, true
    }
    if arg == "-o" {
      if i + 1 < args.length() {
        converted.push(output_flag(args[i + 1], compile_only))
        continue i + 2, compile_only
      } else {
        converted.push(arg)
        continue i + 1, compile_only
      }
    }
    match arg.strip_prefix("-o") {
      Some(path) =>
        if path.is_empty() {
          ()
        } else {
          converted.push(output_flag(path.to_string(), compile_only))
          continue i + 1, compile_only
        }
      None => ()
    }
    if arg == "-I" {
      if i + 1 < args.length() {
        converted.push("/I" + args[i + 1])
        continue i + 2, compile_only
      } else {
        converted.push(arg)
        continue i + 1, compile_only
      }
    }
    match arg.strip_prefix("-I") {
      Some(path) =>
        if path.is_empty() {
          ()
        } else {
          converted.push("/I" + path.to_string())
          continue i + 1, compile_only
        }
      None => ()
    }
    if should_drop_gcc_flag(arg) {
      continue i + 1, compile_only
    }
    converted.push(arg)
    continue i + 1, compile_only
  } nobreak {
    converted
  }
}

///|
#cfg(platform="windows")
fn output_flag(path : String, compile_only : Bool) -> String {
  if compile_only {
    "/Fo" + path
  } else {
    "/Fe" + path
  }
}

///|
#cfg(platform="windows")
fn should_drop_gcc_flag(arg : String) -> Bool {
  arg is ("-g" | "-Og" | "-fwrapv" | "-fno-strict-aliasing" | "-lm")
}

///|
#cfg(platform="windows")
test "normalize windows args translates output and include flags" {
  let input = [
    "-o", "C:/tmp/app.exe", "-IC:/tmp/include", "-g", "-fwrapv", "main.c", "runtime.obj",
    "-lm",
  ]
  assert_eq(normalize_windows_args(input), [
    "/FeC:/tmp/app.exe", "/IC:/tmp/include", "main.c", "runtime.obj",
  ])
}

///|
#cfg(platform="windows")
test "normalize windows args uses /Fo in compile-only mode" {
  assert_eq(normalize_windows_args(["-c", "native.c", "-o", "native.obj"]), [
    "/c", "native.c", "/Fonative.obj",
  ])
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
