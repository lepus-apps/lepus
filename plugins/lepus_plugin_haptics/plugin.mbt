///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("haptics", _ => ())
}
