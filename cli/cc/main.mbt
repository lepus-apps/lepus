///|
enum Platform {
  Windows
  Linux
  MacOS
  Solaris
  BSD
  Unknown
}

///|
/// proxy of c compiler for cross platform
fn main {
  let args = @env.args()
  let platform = get_platform()
  let (compiler, compiler_args) = match platform {
    Windows => ("cl.exe", [..args, "/nologo", "/EHsc"])
    MacOS => ("cc", [..args, "-Lwebview/lib", "-lwebview", "-Wl,-rpath,@loader_path/../../../../../../webview/lib"])
    Linux => ("cc", [..args, ""])
  }
}

///|
#cfg(platform="windows")
fn get_platform() -> Platform {
  Windows
}

///|
#cfg(not(platform="windows"))
fn get_platform() -> Platform {
  match @env.get_env_var("OSTYPE") {
    Some(ostype) if ostype.contains("darwin") => MacOS
    Some(ostype) if ostype.contains("solaris") => Solaris
    Some(ostype) if ostype.contains("freebsd") ||
      ostype.contains("openbsd") ||
      ostype.contains("netbsd") => BSD
    _ => Unknown
  }
}
