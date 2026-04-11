///|
#borrow(title, body)
extern "C" fn notify_ffi(title : Bytes, body : Bytes) -> Int = "lp_notify_send"

///|
extern "C" fn last_error_message_ffi() -> Bytes = "lp_notify_last_error_message"

///|
fn decode_error(bytes : Bytes) -> String {
  let msg = @utf8.decode_lossy(bytes[:])
  if msg.is_empty() {
    "notification send failed"
  } else {
    msg
  }
}

///|
pub fn send_notification(title : String, body : String) -> Result[Unit, String] {
  let rc = notify_ffi(@utf8.encode(title), @utf8.encode(body))
  if rc == 0 {
    Ok(())
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}
