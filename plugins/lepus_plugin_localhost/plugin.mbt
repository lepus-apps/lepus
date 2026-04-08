///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("localhost", _ => ())
}
