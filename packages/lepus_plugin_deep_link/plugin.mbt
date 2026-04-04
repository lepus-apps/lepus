///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("deep-link", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{href:location.href,protocol:location.protocol,hash:location.hash}}",
    )
  })
}
