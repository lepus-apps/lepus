///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("geolocation", _ => ())
}
