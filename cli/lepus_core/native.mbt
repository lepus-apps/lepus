///|
#borrow(command)
pub extern "C" fn command_exists(command : Bytes) -> Int = "lepus_command_exists"

///|
pub extern "C" fn current_dir() -> Bytes = "lepus_current_dir"

///|
pub extern "C" fn platform_name() -> Bytes = "lepus_platform_name"

///|
pub fn getenv(name : String) -> String? {
  @env.get_env_var(name)
}

///|
pub fn has_command(command : String) -> Bool {
  command_exists(@encoding/utf8.encode(command)) != 0
}

///|
pub fn get_cwd() -> String {
  @encoding/utf8.decode(current_dir()) catch {
    _ => "."
  }
}

///|
pub fn get_platform() -> String {
  @encoding/utf8.decode(platform_name()) catch {
    _ => "unknown"
  }
}
