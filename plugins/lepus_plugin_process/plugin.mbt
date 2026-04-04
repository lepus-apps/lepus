///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("process", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{href:location.href,visibility:document.visibilityState,online:navigator.onLine,historyLength:history.length}}",
    )
  })
}
