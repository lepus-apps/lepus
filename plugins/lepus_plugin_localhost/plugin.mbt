///|
pub struct StartRequest {
  root : String
  port : Int
} derive(ToJson, FromJson)

///|
pub struct LocalhostState {
  running : Bool
  port : Int
  pid : Int?
  error : String?
} derive(ToJson, FromJson)

///|
let last_pid : Ref[Int?] = { val: None }

///|
let last_port : Ref[Int] = { val: 0 }

///|
fn start_reply(payload : StartRequest) -> LocalhostState {
  match start_server(payload.root, payload.port) {
    Ok(pid) => {
      last_pid.val = Some(pid)
      last_port.val = payload.port
      { running: true, port: payload.port, pid: Some(pid), error: None }
    }
    Err(message) =>
      { running: false, port: payload.port, pid: None, error: Some(message) }
  }
}

///|
fn stop_reply() -> LocalhostState {
  match stop_server() {
    Ok(_) => {
      last_pid.val = None
      { running: false, port: last_port.val, pid: None, error: None }
    }
    Err(message) =>
      {
        running: running(),
        port: last_port.val,
        pid: last_pid.val,
        error: Some(message),
      }
  }
}

///|
fn status_reply() -> LocalhostState {
  { running: running(), port: last_port.val, pid: last_pid.val, error: None }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("localhost", plugin => {
    plugin.command_sync("start", (payload : StartRequest) => {
      start_reply(payload)
    })
    plugin.command_sync("stop", (_ : Json) => stop_reply())
    plugin.command_sync("status", (_ : Json) => status_reply())
  })
}
