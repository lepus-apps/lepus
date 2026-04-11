///|
extern "C" fn pulse_ffi(intensity : Int) -> Int = "lp_haptics_pulse"

///|
extern "C" fn last_error_message_ffi() -> Bytes = "lp_haptics_last_error_message"

///|
fn decode_error(bytes : Bytes) -> String {
  let msg = @utf8.decode_lossy(bytes[:])
  if msg.is_empty() {
    "haptics pulse failed"
  } else {
    msg
  }
}

///|
pub fn pulse_native(intensity : Int) -> Result[Unit, String] {
  let rc = pulse_ffi(intensity)
  if rc == 0 {
    Ok(())
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}
