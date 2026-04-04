///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("nfc", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{supported:'NDEFReader'in window}}",
    )
  })
}
