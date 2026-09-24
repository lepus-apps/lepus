///|
pub fn get_platform() -> String {
  match @env.get_env_var("LEPUS_PLATFORM") {
    Some(p) if !p.is_empty() => p.to_lower()
    _ => detect_platform_from_env()
  }
}

///|
fn detect_platform_from_env() -> String {
  // OSTYPE is set by bash/zsh on Unix systems
  match @env.get_env_var("OSTYPE") {
    Some(t) if t.has_prefix("darwin") => "macos"
    Some(t) if t.has_prefix("linux") => "linux"
    Some(t) if t.has_prefix("msys") ||
      t.has_prefix("cygwin") ||
      t.has_prefix("win32") => "windows"
    _ =>
      // Windows sets OS=Windows_NT
      match @env.get_env_var("OS") {
        Some(os) if os == "Windows_NT" => "windows"
        _ => "unknown"
      }
  }
}

///|
pub async fn has_command(command : String) -> Bool {
  let platform = get_platform()
  let (cmd, args) = if platform == "windows" {
    ("where", [command])
  } else {
    ("which", [command])
  }
  let exit_code = @process.run(cmd, args)
  exit_code == 0
}

///|
pub fn get_cwd() -> String {
  match @env.current_dir() {
    Some(d) => d
    None => "."
  }
}
