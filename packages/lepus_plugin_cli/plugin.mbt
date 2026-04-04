///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("cli", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{href:location.href,args:location.search?location.search.slice(1).split('&').filter(Boolean):[]}}",
    )
  })
}
