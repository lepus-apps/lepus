///|
pub(all) suberror OpenerError {
  OpenerError(String)
} derive(Eq, Debug)

///|
extern "C" fn platform_supported_ffi() -> Bool = "lp_opener_platform_supported"

///|
#borrow(target)
extern "C" fn open_ffi(target : Bytes) -> Int = "lp_opener_open"

///|
extern "C" fn last_error_message_ffi() -> Bytes = "lp_opener_last_error_message"

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
pub fn is_supported() -> Bool {
  platform_supported_ffi()
}

///|
pub fn open_target(target : String) -> Unit raise OpenerError {
  guard is_supported() else {
    raise OpenerError(
      "opener plugin supports Windows, macOS, and Linux native builds only",
    )
  }
  guard !target.trim(char_set=" \n\r\t").is_empty() else {
    raise OpenerError("target is empty")
  }
  let code = open_ffi(@utf8.encode(target))
  guard code == 0 else {
    raise OpenerError(
      decode_error_message(last_error_message_ffi(), "open target failed"),
    )
  }
}
