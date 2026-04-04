///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("cli", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{href:location.href,args:location.search?location.search.slice(1).split('&').filter(Boolean):[]}}",
    )
  })
}
