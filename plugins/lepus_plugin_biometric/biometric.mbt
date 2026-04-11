///|
extern "C" fn available_ffi() -> Int = "lp_biometric_available"

///|
#borrow(reason)
extern "C" fn authenticate_ffi(reason : Bytes) -> Int = "lp_biometric_authenticate"

///|
extern "C" fn last_error_message_ffi() -> Bytes = "lp_biometric_last_error_message"

///|
fn decode_error(bytes : Bytes) -> String {
  let msg = @utf8.decode_lossy(bytes[:])
  if msg.is_empty() {
    "biometric auth failed"
  } else {
    msg
  }
}

///|
pub fn is_available() -> Bool {
  available_ffi() == 1
}

///|
pub fn authenticate_native(reason : String) -> Result[Bool, String] {
  let rc = authenticate_ffi(@utf8.encode(reason))
  if rc == 1 {
    Ok(true)
  } else if rc == 0 {
    Ok(false)
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}
