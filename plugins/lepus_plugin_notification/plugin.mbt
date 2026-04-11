///|
pub struct NotifyRequest {
  title : String
  body : String
} derive(ToJson, FromJson)

///|
pub struct NotifyReply {
  ok : Bool
  error : String?
} derive(ToJson, FromJson)

///|
fn send_reply(payload : NotifyRequest) -> NotifyReply {
  match send_notification(payload.title, payload.body) {
    Ok(_) => { ok: true, error: None }
    Err(message) => { ok: false, error: Some(message) }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("notification", plugin => {
    plugin.command_sync("send", (payload : NotifyRequest) => send_reply(payload))
  })
}
