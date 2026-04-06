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
  // `-c` may appear after `-o`; determine compile mode first so `-o` maps to
  // `/Fo` consistently in compile-only invocations.
  let compile_only = is_compile_only_mode(args)
  for i = 0; i < args.length(); {
    let arg = args[i]
    if arg == "-c" {
      converted.push("/c")
      continue i + 1
    }
    if arg == "-o" {
      if i + 1 < args.length() {
        converted.push(output_flag(args[i + 1], compile_only))
        continue i + 2
      } else {
        converted.push(arg)
        continue i + 1
      }
    }
    match arg.strip_prefix("-o") {
      Some(path) =>
        if path.is_empty() {
          ()
        } else {
          converted.push(output_flag(path.to_string(), compile_only))
          continue i + 1
        }
      None => ()
    }
    if arg == "-I" {
      if i + 1 < args.length() {
        converted.push("/I" + args[i + 1])
        continue i + 2
      } else {
        converted.push(arg)
        continue i + 1
      }
    }
    match arg.strip_prefix("-I") {
      Some(path) =>
        if path.is_empty() {
          ()
        } else {
          converted.push("/I" + path.to_string())
          continue i + 1
        }
      None => ()
    }
    if should_drop_gcc_flag(arg) {
      continue i + 1
    }
    converted.push(arg)
    continue i + 1
  } nobreak {
    // `cl.exe` writes intermediate objects to the current working directory
    // when `/Fo` is missing; on project-root invocations this becomes `*.obj`
    // pollution at repository root.
    if has_object_output_flag(converted) {
      converted
    } else {
      [..converted, infer_object_output_flag(converted)]
    }
  }
}

///|
#cfg(platform="windows")
fn is_compile_only_mode(args : Array[String]) -> Bool {
  for arg in args {
    if arg is ("-c" | "/c") {
      return true
    }
  } nobreak {
    false
  }
}

///|
#cfg(platform="windows")
fn has_object_output_flag(args : Array[String]) -> Bool {
  for arg in args {
    if arg.has_prefix("/Fo") {
      return true
    }
  } nobreak {
    false
  }
}

///|
#cfg(platform="windows")
fn infer_object_output_flag(args : Array[String]) -> String {
  // Prefer placing intermediate objects beside `/Fe` output when available.
  for arg in args {
    match arg.strip_prefix("/Fe") {
      Some(path) =>
        match dirname_with_separator(path.to_string()) {
          Some(dir) => return "/Fo" + dir
          None => ()
        }
      None => ()
    }
  } nobreak {
    "/Fo_build/"
  }
}

///|
#cfg(platform="windows")
fn dirname_with_separator(path : String) -> String? {
  let slash = path.rev_find("/")
  let backslash = path.rev_find("\\")
  match (slash, backslash) {
    (Some(a), Some(b)) =>
      Some(path.sub(end=if a > b { a + 1 } else { b + 1 }).to_string())
    (Some(a), None) => Some(path.sub(end=a + 1).to_string())
    (None, Some(b)) => Some(path.sub(end=b + 1).to_string())
    _ => None
  }
}

///|
#cfg(platform="windows")
fn output_flag(path : String, compile_only : Bool) -> String {
  if compile_only {
    "/Fo" + normalize_object_output_path(path)
  } else {
    "/Fe" + path
  }
}

///|
#cfg(platform="windows")
fn normalize_object_output_path(path : String) -> String {
  // Relative `native.obj` still lands in current working directory on MSVC.
  // Prefix `_build/` so Windows builds do not pollute repository root.
  if path.contains(":") || path.contains("/") || path.contains("\\") {
    path
  } else {
    "_build/" + path
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
    "/FeC:/tmp/app.exe", "/IC:/tmp/include", "main.c", "runtime.obj", "/FoC:/tmp/",
  ])
}

///|
#cfg(platform="windows")
test "normalize windows args uses /Fo in compile-only mode" {
  assert_eq(normalize_windows_args(["-c", "native.c", "-o", "native.obj"]), [
    "/c", "native.c", "/Fo_build/native.obj",
  ])
}

///|
#cfg(platform="windows")
test "normalize windows args handles -o before -c" {
  assert_eq(normalize_windows_args(["-o", "native.obj", "-c", "native.c"]), [
    "/Fo_build/native.obj", "/c", "native.c",
  ])
}

///|
#cfg(platform="windows")
test "normalize windows args adds fallback /Fo for implicit outputs" {
  assert_eq(normalize_windows_args(["native.c"]), ["native.c", "/Fo_build/"])
}

///|
#cfg(platform="windows")
test "normalize windows args infers /Fo from /Fe output directory" {
  assert_eq(
    normalize_windows_args(["native.c", "-o", "_build/native/debug/app.exe"]),
    ["native.c", "/Fe_build/native/debug/app.exe", "/Fo_build/native/debug/"],
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
