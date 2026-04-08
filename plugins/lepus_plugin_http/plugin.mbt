///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("http", _ => ())
}
