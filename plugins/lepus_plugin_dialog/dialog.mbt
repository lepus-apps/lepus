///|
#borrow(title, message)
extern "C" fn alert_ffi(title : Bytes, message : Bytes, level : Int) -> Int = "lp_dialog_alert"

///|
#borrow(title, message)
extern "C" fn confirm_ffi(
  title : Bytes,
  message : Bytes,
  default_ok : Int,
) -> Int = "lp_dialog_confirm"

///|
extern "C" fn last_error_message_ffi() -> Bytes = "lp_dialog_last_error_message"

///|
fn decode_error(bytes : Bytes) -> String {
  let msg = @utf8.decode_lossy(bytes[:])
  if msg.is_empty() {
    "dialog operation failed"
  } else {
    msg
  }
}

///|
fn alert_native(
  title : String,
  message : String,
  level : DialogLevel,
) -> Result[Unit, String] {
  let lv = match level {
    DialogLevel::Info => 0
    DialogLevel::Warning => 1
    DialogLevel::Error => 2
  }
  let rc = alert_ffi(@utf8.encode(title), @utf8.encode(message), lv)
  if rc == 0 {
    Ok(())
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}

///|
fn confirm_native(
  title : String,
  message : String,
  default_ok : Bool,
) -> Result[Bool, String] {
  let rc = confirm_ffi(
    @utf8.encode(title),
    @utf8.encode(message),
    if default_ok {
      1
    } else {
      0
    },
  )
  if rc >= 0 {
    Ok(rc == 1)
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}
