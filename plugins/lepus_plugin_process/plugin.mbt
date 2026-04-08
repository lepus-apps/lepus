///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("process", _ => ())
}
