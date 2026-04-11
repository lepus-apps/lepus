///|
pub struct WindowBounds {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(ToJson, FromJson)

///|
pub struct PositionRequest {
  window : String
  bounds : WindowBounds
} derive(ToJson, FromJson)

///|
let positioned_windows : Ref[Map[String, WindowBounds]] = { val: {} }

///|
fn set_bounds(payload : PositionRequest) -> WindowBounds {
  positioned_windows.val.set(payload.window, payload.bounds)
  payload.bounds
}

///|
fn get_bounds(window : String) -> WindowBounds? {
  positioned_windows.val.get(window)
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("positioner", plugin => {
    plugin.command_sync("set_bounds", (payload : PositionRequest) => {
      set_bounds(payload)
    })
    plugin.command_sync("get_bounds", (payload : String) => get_bounds(payload))
  })
}
