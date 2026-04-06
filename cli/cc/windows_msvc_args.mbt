///|
#cfg(platform="windows")
fn normalize_windows_args(args : Array[String]) -> Array[String] {
  let compile_only = is_compile_only_mode(args)
  ensure_object_output_flag(rewrite_windows_args(args, 0, compile_only, []))
}

///|
#cfg(platform="windows")
fn rewrite_windows_args(
  args : Array[String],
  index : Int,
  compile_only : Bool,
  acc : Array[String],
) -> Array[String] {
  if index >= args.length() {
    acc
  } else {
    let arg = args[index]
    match rewrite_special_arg(args, index, compile_only) {
      Some((step, rewritten)) =>
        rewrite_windows_args(
          args,
          index + step,
          compile_only,
          [..acc, ..rewritten],
        )
      None =>
        if should_drop_gcc_flag(arg) {
          rewrite_windows_args(args, index + 1, compile_only, acc)
        } else {
          rewrite_windows_args(args, index + 1, compile_only, [..acc, arg])
        }
    }
  }
}

///|
#cfg(platform="windows")
fn rewrite_special_arg(
  args : Array[String],
  index : Int,
  compile_only : Bool,
) -> (Int, Array[String])? {
  let arg = args[index]
  if arg == "-c" {
    return Some((1, ["/c"]))
  }
  if arg == "-o" {
    return Some(rewrite_output_pair(args, index, compile_only))
  }
  match arg.strip_prefix("-o") {
    Some(path) =>
      if path.is_empty() {
        ()
      } else {
        return Some((1, [output_flag(path.to_string(), compile_only)]))
      }
    None => ()
  }
  if arg == "-I" {
    return Some(rewrite_include_pair(args, index))
  }
  match arg.strip_prefix("-I") {
    Some(path) =>
      if path.is_empty() {
        None
      } else {
        Some((1, ["/I" + path.to_string()]))
      }
    None => None
  }
}

///|
#cfg(platform="windows")
fn rewrite_output_pair(
  args : Array[String],
  index : Int,
  compile_only : Bool,
) -> (Int, Array[String]) {
  if index + 1 < args.length() {
    (2, [output_flag(args[index + 1], compile_only)])
  } else {
    (1, ["-o"])
  }
}

///|
#cfg(platform="windows")
fn rewrite_include_pair(
  args : Array[String],
  index : Int,
) -> (Int, Array[String]) {
  if index + 1 < args.length() {
    (2, ["/I" + args[index + 1]])
  } else {
    (1, ["-I"])
  }
}

///|
#cfg(platform="windows")
fn ensure_object_output_flag(args : Array[String]) -> Array[String] {
  if has_object_output_flag(args) {
    args
  } else {
    [..args, infer_object_output_flag(args)]
  }
}

///|
#cfg(platform="windows")
fn is_compile_only_mode(args : Array[String]) -> Bool {
  contains_compile_only_flag(args, 0)
}

///|
#cfg(platform="windows")
fn contains_compile_only_flag(args : Array[String], index : Int) -> Bool {
  if index >= args.length() {
    false
  } else {
    let arg = args[index]
    if arg is ("-c" | "/c") {
      true
    } else {
      contains_compile_only_flag(args, index + 1)
    }
  }
}

///|
#cfg(platform="windows")
fn has_object_output_flag(args : Array[String]) -> Bool {
  find_object_output_flag(args, 0)
}

///|
#cfg(platform="windows")
fn find_object_output_flag(args : Array[String], index : Int) -> Bool {
  if index >= args.length() {
    false
  } else if args[index].has_prefix("/Fo") {
    true
  } else {
    find_object_output_flag(args, index + 1)
  }
}

///|
#cfg(platform="windows")
fn infer_object_output_flag(args : Array[String]) -> String {
  infer_object_output_flag_from_exe(args, 0).unwrap_or("/Fo_build/")
}

///|
#cfg(platform="windows")
fn infer_object_output_flag_from_exe(
  args : Array[String],
  index : Int,
) -> String? {
  if index >= args.length() {
    None
  } else {
    match args[index].strip_prefix("/Fe") {
      Some(path) =>
        match dirname_with_separator(path.to_string()) {
          Some(dir) => Some("/Fo" + dir)
          None => infer_object_output_flag_from_exe(args, index + 1)
        }
      None => infer_object_output_flag_from_exe(args, index + 1)
    }
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
