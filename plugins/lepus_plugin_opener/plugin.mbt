///|
pub struct OpenReply {
  ok : Bool
  error : String?
} derive(ToJson, FromJson)

///|
fn open_reply(target : String) -> OpenReply {
  try {
    open_target(target)
    { ok: true, error: None }
  } catch {
    OpenerError(message) => { ok: false, error: Some(message) }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("opener", plugin => {
    plugin.command_sync("open", (payload : String) => open_reply(payload))
    plugin.command_sync("is_supported", (_ : Json) => is_supported())
  })
}
