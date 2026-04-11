///|
#borrow(app_id)
extern "C" fn status_ffi(app_id : Bytes) -> Int = "lp_autostart_status"

///|
#borrow(app_id, exec_path, args)
extern "C" fn enable_ffi(
  app_id : Bytes,
  exec_path : Bytes,
  args : Bytes,
) -> Int = "lp_autostart_enable"

///|
#borrow(app_id)
extern "C" fn disable_ffi(app_id : Bytes) -> Int = "lp_autostart_disable"

///|
extern "C" fn last_error_message_ffi() -> Bytes = "lp_autostart_last_error_message"

///|
fn decode_error(bytes : Bytes) -> String {
  let msg = @utf8.decode_lossy(bytes[:])
  if msg.is_empty() {
    "autostart operation failed"
  } else {
    msg
  }
}

///|
pub fn status(app_id : String) -> Result[Bool, String] {
  let rc = status_ffi(@utf8.encode(app_id))
  if rc == 1 {
    Ok(true)
  } else if rc == 0 {
    Ok(false)
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}

///|
pub fn enable(
  app_id : String,
  exec_path : String,
  args : String,
) -> Result[Unit, String] {
  if enable_ffi(
      @utf8.encode(app_id),
      @utf8.encode(exec_path),
      @utf8.encode(args),
    ) ==
    0 {
    Ok(())
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}

///|
pub fn disable(app_id : String) -> Result[Unit, String] {
  if disable_ffi(@utf8.encode(app_id)) == 0 {
    Ok(())
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}
