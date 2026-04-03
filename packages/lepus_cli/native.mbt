///|
#borrow(name)
pub extern "C" fn env_get(name : Bytes) -> Bytes = "lepus_env_get"

///|
#borrow(path)
pub extern "C" fn file_exists(path : Bytes) -> Int = "lepus_file_exists"

///|
#borrow(command)
pub extern "C" fn command_exists(command : Bytes) -> Int = "lepus_command_exists"

///|
pub extern "C" fn current_dir() -> Bytes = "lepus_current_dir"

///|
pub extern "C" fn platform_name() -> Bytes = "lepus_platform_name"

///|
pub extern "C" fn exit_process(code : Int) -> Unit = "lepus_exit"

///|
fn bytes_to_string(bytes : Bytes) -> String {
  @ffi.from_cstr(bytes)
}

///|
pub fn getenv(name : String) -> String? {
  let value = bytes_to_string(env_get(@ffi.to_cstr(name)))
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
pub fn path_exists(path : String) -> Bool {
  file_exists(@ffi.to_cstr(path)) != 0
}

///|
pub fn has_command(command : String) -> Bool {
  command_exists(@ffi.to_cstr(command)) != 0
}

///|
pub fn get_cwd() -> String {
  bytes_to_string(current_dir())
}

///|
pub fn get_platform() -> String {
  bytes_to_string(platform_name())
}
