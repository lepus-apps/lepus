///|
#borrow(root)
extern "C" fn start_server_ffi(root : Bytes, port : Int) -> Int = "lp_localhost_start"

///|
extern "C" fn stop_server_ffi() -> Int = "lp_localhost_stop"

///|
extern "C" fn status_server_ffi() -> Int = "lp_localhost_status"

///|
extern "C" fn last_error_message_ffi() -> Bytes = "lp_localhost_last_error_message"

///|
fn decode_error(bytes : Bytes) -> String {
  let msg = @utf8.decode_lossy(bytes[:])
  if msg.is_empty() {
    "localhost plugin error"
  } else {
    msg
  }
}

///|
pub fn start_server(root : String, port : Int) -> Result[Int, String] {
  let pid = start_server_ffi(@utf8.encode(root), port)
  if pid > 0 {
    Ok(pid)
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}

///|
pub fn stop_server() -> Result[Unit, String] {
  if stop_server_ffi() == 0 {
    Ok(())
  } else {
    Err(decode_error(last_error_message_ffi()))
  }
}

///|
pub fn running() -> Bool {
  status_server_ffi() == 1
}
