///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("window-state", _ => ())
}
