///|
#borrow(name)
pub extern "C" fn env_get(name : Bytes) -> Bytes = "lepus_env_get"

///|
#borrow(path)
pub extern "C" fn file_exists(path : Bytes) -> Int = "lepus_file_exists"

///|
#borrow(path)
pub extern "C" fn directory_exists(path : Bytes) -> Int = "lepus_directory_exists"

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
pub extern "C" fn repo_root() -> Bytes = "lepus_repo_root"

///|
#borrow(path)
pub extern "C" fn realpath_ffi(path : Bytes) -> Bytes = "lepus_realpath"

///|
#borrow(path)
pub extern "C" fn mkdir_p_ffi(path : Bytes) -> Int = "lepus_mkdir_p"

///|
#borrow(path, content)
pub extern "C" fn write_text_file_ffi(path : Bytes, content : Bytes) -> Int = "lepus_write_text_file"

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
pub fn is_directory(path : String) -> Bool {
  directory_exists(@ffi.to_cstr(path)) != 0
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

///|
pub fn get_repo_root() -> String {
  bytes_to_string(repo_root())
}

///|
pub fn canonicalize_path(path : String) -> String {
  let resolved = bytes_to_string(realpath_ffi(@ffi.to_cstr(path)))
  if resolved == "" {
    path
  } else {
    resolved
  }
}

///|
pub fn mkdir_p(path : String) -> Bool {
  mkdir_p_ffi(@ffi.to_cstr(path)) == 0
}

///|
pub fn write_text_file(path : String, content : String) -> Bool {
  write_text_file_ffi(@ffi.to_cstr(path), @ffi.to_cstr(content)) == 0
}
