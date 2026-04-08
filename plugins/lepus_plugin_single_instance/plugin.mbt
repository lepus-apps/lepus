///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("single-instance", _ => ())
}
