///|
pub struct SingleInstanceAcquireRequest {
  app_id : String
} derive(ToJson, FromJson)

///|
pub struct SingleInstanceAcquireReply {
  acquired : Bool
  error : String?
} derive(ToJson, FromJson)

///|
fn acquire_reply(
  payload : SingleInstanceAcquireRequest,
) -> SingleInstanceAcquireReply {
  if acquire(payload.app_id) {
    { acquired: true, error: None }
  } else {
    { acquired: false, error: Some(last_error()) }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("single_instance", plugin => {
    plugin.command_sync("acquire", (payload : SingleInstanceAcquireRequest) => {
      acquire_reply(payload)
    })
    plugin.command_sync("release", (_ : Json) => {
      release()
      true
    })
  })
}
