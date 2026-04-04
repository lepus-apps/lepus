///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("nfc", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{supported:'NDEFReader'in window}}",
    )
  })
}
