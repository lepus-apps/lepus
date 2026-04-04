///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("haptics", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){const supported=typeof navigator.vibrate==='function';if(supported)navigator.vibrate([60,40,60]);return{supported}}",
    )
  })
}
