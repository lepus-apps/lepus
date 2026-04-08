///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("opener", _ => ())
}
