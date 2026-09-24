///|
pub fn get_platform() -> String {
  @platform.detect_platform().to_string()
}

///|
pub async fn has_command(command : String) -> Bool {
  let platform = @platform.detect_platform()
  let (cmd, args) = if platform is @platform.Windows {
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
