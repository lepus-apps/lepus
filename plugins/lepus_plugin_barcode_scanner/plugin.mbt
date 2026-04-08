///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("barcode_scanner", _ => ())
}
