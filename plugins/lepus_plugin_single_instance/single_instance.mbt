///|
#borrow(app_id)
extern "C" fn acquire_lock_ffi(app_id : Bytes) -> Int = "lp_single_instance_acquire"

///|
extern "C" fn release_lock_ffi() -> Unit = "lp_single_instance_release"

///|
extern "C" fn last_error_message_ffi() -> Bytes = "lp_single_instance_last_error_message"

///|
fn decode_error(bytes : Bytes) -> String {
  let msg = @utf8.decode_lossy(bytes[:])
  if msg.is_empty() {
    "single instance error"
  } else {
    msg
  }
}

///|
pub fn acquire(app_id : String) -> Bool {
  acquire_lock_ffi(@utf8.encode(app_id)) == 0
}

///|
pub fn release() -> Unit {
  release_lock_ffi()
}

///|
pub fn last_error() -> String {
  decode_error(last_error_message_ffi())
}
