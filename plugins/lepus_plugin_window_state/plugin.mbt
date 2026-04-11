///|
pub struct WindowState {
  x : Int
  y : Int
  width : Int
  height : Int
  maximized : Bool
} derive(ToJson, FromJson)

///|
pub struct SaveRequest {
  window_id : String
  state : WindowState
} derive(ToJson, FromJson)

///|
let state_map : Ref[Map[String, WindowState]] = { val: {} }

///|
fn save_state(payload : SaveRequest) -> Bool {
  state_map.val.set(payload.window_id, payload.state)
  true
}

///|
fn load_state(window_id : String) -> WindowState? {
  state_map.val.get(window_id)
}

///|
fn clear_state(window_id : String) -> Bool {
  state_map.val.remove(window_id)
  true
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("window_state", plugin => {
    plugin.command_sync("save_state", (payload : SaveRequest) => {
      save_state(payload)
    })
    plugin.command_sync("load_state", (payload : String) => load_state(payload))
    plugin.command_sync("clear_state", (payload : String) => {
      clear_state(payload)
    })
  })
}
