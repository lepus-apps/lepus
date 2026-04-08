///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("fs", _ => ())
}
