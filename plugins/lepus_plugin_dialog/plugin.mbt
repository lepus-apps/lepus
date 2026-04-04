///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("dialog", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){const accepted=window.confirm('Lepus dialog plugin example. Click OK to continue.');return{accepted}}",
    )
  })
}
