///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("barcode-scanner", _ => ())
}
