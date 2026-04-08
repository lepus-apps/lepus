///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("notification", _ => ())
}
