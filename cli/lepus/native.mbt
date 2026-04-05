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
pub fn getenv(name : String) -> String? {
  @env.get_env_var(name)
}

///|
pub fn path_exists(path : String) -> Bool {
  file_exists(@encoding/utf8.encode(path)) != 0
}

///|
pub fn is_directory(path : String) -> Bool {
  directory_exists(@encoding/utf8.encode(path)) != 0
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

///|
pub fn get_repo_root() -> String {
  @encoding/utf8.decode(repo_root()) catch {
    _ => "."
  }
}

///|
pub fn canonicalize_path(path : String) -> String {
  let resolved = @encoding/utf8.decode(
    realpath_ffi(@encoding/utf8.encode(path)),
  ) catch {
    _ => path
  }
  if resolved == "" {
    path
  } else {
    resolved
  }
}

///|
pub fn mkdir_p(path : String) -> Bool {
  mkdir_p_ffi(@encoding/utf8.encode(path)) == 0
}

///|
pub fn write_text_file(path : String, content : String) -> Bool {
  write_text_file_ffi(
    @encoding/utf8.encode(path),
    @encoding/utf8.encode(content),
  ) ==
  0
}
