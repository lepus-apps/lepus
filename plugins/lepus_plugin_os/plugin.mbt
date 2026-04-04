///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("os", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{platform:navigator.platform,userAgent:navigator.userAgent,language:navigator.language,online:navigator.onLine}}",
    )
  })
}
