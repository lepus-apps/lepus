///|
pub(all) suberror ClipboardError {
  ClipboardError(String)
} derive(Eq, Debug)

///|
/// Returns whether the native backend is available on the current target.
extern "C" fn platform_supported_ffi() -> Bool = "mb_clipboard_platform_supported"

///|
/// Reads raw clipboard text bytes from the native backend.
extern "C" fn read_text_ffi() -> Bytes = "mb_clipboard_read_text"

///|
/// Writes UTF-8 encoded text bytes to the native backend.
#borrow(text)
extern "C" fn write_text_ffi(text : Bytes) -> Int = "mb_clipboard_write_text"

///|
/// Returns the last backend error code.
extern "C" fn last_error_code_ffi() -> Int = "mb_clipboard_last_error_code"

///|
/// Returns the last backend error message.
extern "C" fn last_error_message_ffi() -> Bytes = "mb_clipboard_last_error_message"

///|
fn decode_optional_text(bytes : Bytes) -> String? {
  let value = @utf8.decode_lossy(bytes[:])
  if value.is_empty() {
    None
  } else {
    Some(value)
  }
}

///|
fn decode_error_message(bytes : Bytes, default : String) -> String {
  let value = @utf8.decode_lossy(bytes[:])
  if value.is_empty() {
    default
  } else {
    value
  }
}

///|
fn unsupported_error_message() -> String {
  "clipboard plugin currently supports Windows, macOS, and Linux native builds only"
}

///|
fn raise_backend_error(message : String) -> Unit raise ClipboardError {
  raise ClipboardError(message)
}

///|
fn ensure_supported_result(supported : Bool) -> Unit raise ClipboardError {
  guard supported else { raise_backend_error(unsupported_error_message()) }
}

///|
fn read_text_result(
  supported : Bool,
  bytes : Bytes,
  error_code : Int,
  error_message : Bytes,
) -> String? raise ClipboardError {
  ensure_supported_result(supported)
  guard error_code == 0 else {
    raise ClipboardError(
      decode_error_message(error_message, "clipboard read failed"),
    )
  }
  decode_optional_text(bytes)
}

///|
fn write_text_result(
  supported : Bool,
  status : Int,
  error_message : Bytes,
) -> Unit raise ClipboardError {
  ensure_supported_result(supported)
  guard status == 0 else {
    raise ClipboardError(
      decode_error_message(error_message, "clipboard write failed"),
    )
  }
}

///|
fn read_text_with(
  supported : Bool,
  read : () -> Bytes,
  get_error_code : () -> Int,
  get_error_message : () -> Bytes,
) -> String? raise ClipboardError {
  read_text_result(supported, read(), get_error_code(), get_error_message())
}

///|
fn write_text_with(
  supported : Bool,
  text : String,
  write : (Bytes) -> Int,
  get_error_message : () -> Bytes,
) -> Unit raise ClipboardError {
  write_text_result(supported, write(@utf8.encode(text)), get_error_message())
}

///|
pub fn is_supported() -> Bool {
  platform_supported_ffi()
}

///|
pub fn ensure_supported() -> Unit raise ClipboardError {
  ensure_supported_result(is_supported())
}

///|
pub fn read_text() -> String? raise ClipboardError {
  read_text_with(
    is_supported(),
    read_text_ffi,
    last_error_code_ffi,
    last_error_message_ffi,
  )
}

///|
pub fn write_text(text : String) -> Unit raise ClipboardError {
  write_text_with(is_supported(), text, write_text_ffi, last_error_message_ffi)
}

///|
pub fn clear() -> Unit raise ClipboardError {
  write_text("")
}

///|
pub fn has_text() -> Bool raise ClipboardError {
  match read_text() {
    Some(text) => !text.is_empty()
    None => false
  }
}

///|
#skip
test {
  ensure_supported()
  write_text("Hello, world!")
  inspect(
    read_text(),
    content=(
      #|Some("Hello, world!")
    ),
  )
  clear()
  inspect(
    read_text(),
    content=(
      #|None
    ),
  )
}
