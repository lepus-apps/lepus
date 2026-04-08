///|
pub struct ClipboardTextReply {
  supported : Bool
  text : String?
  error : String?
} derive(ToJson, FromJson)

///|
pub struct ClipboardWriteRequest {
  text : String
} derive(ToJson, FromJson)

///|
pub struct ClipboardWriteReply {
  ok : Bool
  error : String?
} derive(ToJson, FromJson)

///|
pub struct ClipboardBoolReply {
  supported : Bool
  value : Bool
  error : String?
} derive(ToJson, FromJson)

///|
pub struct ClipboardExampleReply {
  supported : Bool
  before : String?
  after : String?
  restored : Bool
  error : String?
} derive(ToJson, FromJson)

///|
fn read_reply() -> ClipboardTextReply {
  { supported: true, text: read_text(), error: None } catch {
    ClipboardError(message) =>
      { supported: is_supported(), text: None, error: Some(message) }
  }
}

///|
fn write_reply(text : String) -> ClipboardWriteReply {
  try {
    write_text(text)
    { ok: true, error: None }
  } catch {
    ClipboardError(message) => { ok: false, error: Some(message) }
  }
}

///|
fn clear_reply() -> ClipboardWriteReply {
  try {
    clear()
    { ok: true, error: None }
  } catch {
    ClipboardError(message) => { ok: false, error: Some(message) }
  }
}

///|
fn has_text_reply() -> ClipboardBoolReply {
  { supported: true, value: has_text(), error: None } catch {
    ClipboardError(message) =>
      { supported: is_supported(), value: false, error: Some(message) }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("clipboard_manager", plugin => {
    plugin.command("read_text", (_ : Json) => read_reply())
    plugin.command("write_text", (payload : String) => write_reply(payload))
    plugin.command("clear", (_ : Json) => clear_reply())
    plugin.command("has_text", (_ : Json) => has_text_reply())
  })
}
