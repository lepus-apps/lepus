///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("log", _ => ())
}
