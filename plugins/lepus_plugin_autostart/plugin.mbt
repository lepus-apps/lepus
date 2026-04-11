///|
pub struct AutostartConfig {
  app_id : String
  exec_path : String
  args : String?
} derive(ToJson, FromJson)

///|
pub struct AutostartStatusReply {
  ok : Bool
  enabled : Bool
  error : String?
} derive(ToJson, FromJson)

///|
let test_app_id : String = "lepus.test.app"

///|
fn status_reply(app_id : String) -> AutostartStatusReply {
  match status(app_id) {
    Ok(enabled) => { ok: true, enabled, error: None }
    Err(message) => { ok: false, enabled: false, error: Some(message) }
  }
}

///|
fn enable_reply(payload : AutostartConfig) -> AutostartStatusReply {
  match enable(payload.app_id, payload.exec_path, payload.args.unwrap_or("")) {
    Ok(_) => status_reply(payload.app_id)
    Err(message) => { ok: false, enabled: false, error: Some(message) }
  }
}

///|
fn disable_reply(app_id : String) -> AutostartStatusReply {
  match disable(app_id) {
    Ok(_) => status_reply(app_id)
    Err(message) => { ok: false, enabled: false, error: Some(message) }
  }
}

///|
pub fn set_enabled(enabled : Bool) -> AutostartStatusReply {
  if enabled {
    enable_reply({ app_id: test_app_id, exec_path: "lepus", args: None })
  } else {
    disable_reply(test_app_id)
  }
}

///|
pub fn get_status() -> AutostartStatusReply {
  status_reply(test_app_id)
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("autostart", plugin => {
    plugin.command_sync("status", (payload : String) => status_reply(payload))
    plugin.command_sync("enable", (payload : AutostartConfig) => {
      enable_reply(payload)
    })
    plugin.command_sync("disable", (payload : String) => disable_reply(payload))
  })
}
