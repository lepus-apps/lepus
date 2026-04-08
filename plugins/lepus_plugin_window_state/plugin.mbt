///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("window_state", _ => ())
}
