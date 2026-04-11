///|
pub enum DialogLevel {
  Info
  Warning
  Error
} derive(ToJson, FromJson, Debug, Eq)

///|
pub struct DialogRequest {
  title : String?
  message : String
  level : DialogLevel?
} derive(ToJson, FromJson)

///|
pub struct ConfirmRequest {
  title : String?
  message : String
  default_ok : Bool?
} derive(ToJson, FromJson)

///|
pub struct DialogReply {
  shown : Bool
  title : String
  message : String
  level : DialogLevel
  error : String?
} derive(ToJson, FromJson)

///|
pub struct ConfirmReply {
  ok : Bool
  accepted : Bool
  error : String?
} derive(ToJson, FromJson)

///|
fn show_dialog(payload : DialogRequest) -> DialogReply {
  let title = payload.title.unwrap_or("Dialog")
  let level = payload.level.unwrap_or(DialogLevel::Info)
  match alert_native(title, payload.message, level) {
    Ok(_) =>
      { shown: true, title, message: payload.message, level, error: None }
    Err(message) =>
      {
        shown: false,
        title,
        message: payload.message,
        level,
        error: Some(message),
      }
  }
}

///|
fn confirm_dialog(payload : ConfirmRequest) -> ConfirmReply {
  match
    confirm_native(
      payload.title.unwrap_or("Confirm"),
      payload.message,
      payload.default_ok.unwrap_or(true),
    ) {
    Ok(accepted) => { ok: true, accepted, error: None }
    Err(message) => { ok: false, accepted: false, error: Some(message) }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("dialog", plugin => {
    plugin.command_sync("show", (payload : DialogRequest) => {
      show_dialog(payload)
    })
    plugin.command_sync("confirm", (payload : ConfirmRequest) => {
      confirm_dialog(payload)
    })
  })
}
