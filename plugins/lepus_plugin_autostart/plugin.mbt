///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("autostart", _ => ())
}
