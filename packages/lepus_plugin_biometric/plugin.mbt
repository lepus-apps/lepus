///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("biometric", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{supported:!!window.PublicKeyCredential}}",
    )
  })
}
