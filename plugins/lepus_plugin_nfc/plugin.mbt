///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("nfc", _ => ())
}
