///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("barcode-scanner", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{supported:'BarcodeDetector'in window}}",
    )
  })
}
