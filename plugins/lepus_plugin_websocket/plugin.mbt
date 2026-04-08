///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("websocket", _ => ())
}
