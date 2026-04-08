///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("shell", _ => ())
}
