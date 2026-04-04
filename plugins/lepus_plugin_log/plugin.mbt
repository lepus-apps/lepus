///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("log", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){console.debug('lepus log debug example');console.info('lepus log info example');console.warn('lepus log warn example');return{logged:true}}",
    )
  })
}
