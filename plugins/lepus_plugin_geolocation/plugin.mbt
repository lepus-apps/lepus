///|
pub struct GeoPosition {
  latitude : Double
  longitude : Double
  accuracy : Double
} derive(ToJson, FromJson)

///|
let current_geo : Ref[GeoPosition] = {
  val: { latitude: 31.2304, longitude: 121.4737, accuracy: 30.0 },
}

///|
fn get_current() -> GeoPosition {
  current_geo.val
}

///|
fn set_mock(payload : GeoPosition) -> GeoPosition {
  current_geo.val = payload
  current_geo.val
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("geolocation", plugin => {
    plugin.command_sync("get_current", (_ : Json) => get_current())
    plugin.command_sync("set_mock", (payload : GeoPosition) => set_mock(payload))
  })
}
