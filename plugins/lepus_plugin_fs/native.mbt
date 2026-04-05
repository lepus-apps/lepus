///|
#borrow(path)
extern "C" fn fs_exists_ffi(path : Bytes) -> Int = "lepus_fs_exists"

///|
#borrow(path)
extern "C" fn fs_is_dir_ffi(path : Bytes) -> Int = "lepus_fs_is_dir"

///|
#borrow(path)
extern "C" fn fs_read_text_ffi(path : Bytes) -> Bytes = "lepus_fs_read_text"

///|
#borrow(path, content)
extern "C" fn fs_write_text_ffi(path : Bytes, content : Bytes) -> Int = "lepus_fs_write_text"

///|
#borrow(path)
extern "C" fn fs_mkdir_ffi(path : Bytes, recursive : Int) -> Int = "lepus_fs_mkdir"

///|
#borrow(path)
extern "C" fn fs_remove_ffi(path : Bytes, recursive : Int) -> Int = "lepus_fs_remove"

///|
extern "C" fn fs_last_error_ffi() -> Bytes = "lepus_fs_last_error"

///|
fn encode_utf8(value : String) -> Bytes {
  @encoding/utf8.encode(value)
}

///|
fn decode_utf8(value : Bytes) -> String {
  let view = match value.find(b"\x00") {
    Some(index) => value.view(end=index)
    None => value[:]
  }
  @encoding/utf8.decode(view) catch {
    _ => ""
  }
}

///|
fn bool_to_int(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}

///|
fn native_error_or(default_error : String) -> String {
  let message = decode_utf8(fs_last_error_ffi())
  if message == "" {
    default_error
  } else {
    message
  }
}

///|
fn fs_exists(path : String) -> Bool {
  fs_exists_ffi(encode_utf8(path)) != 0
}

///|
fn fs_is_dir(path : String) -> Bool {
  fs_is_dir_ffi(encode_utf8(path)) != 0
}

///|
fn fs_read_text(path : String) -> Result[String, String] {
  let content = decode_utf8(fs_read_text_ffi(encode_utf8(path)))
  let error = decode_utf8(fs_last_error_ffi())
  if error == "" {
    Ok(content)
  } else {
    Err(error)
  }
}

///|
fn fs_write_text(path : String, content : String) -> Result[Unit, String] {
  if fs_write_text_ffi(encode_utf8(path), encode_utf8(content)) == 0 {
    Ok(())
  } else {
    Err(native_error_or("write_text failed"))
  }
}

///|
fn fs_mkdir(path : String, recursive : Bool) -> Result[Unit, String] {
  if fs_mkdir_ffi(encode_utf8(path), bool_to_int(recursive)) == 0 {
    Ok(())
  } else {
    Err(native_error_or("mkdir failed"))
  }
}

///|
fn fs_remove(path : String, recursive : Bool) -> Result[Unit, String] {
  if fs_remove_ffi(encode_utf8(path), bool_to_int(recursive)) == 0 {
    Ok(())
  } else {
    Err(native_error_or("remove failed"))
  }
}
