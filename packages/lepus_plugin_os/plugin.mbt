///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("os", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{platform:navigator.platform,userAgent:navigator.userAgent,language:navigator.language,online:navigator.onLine}}",
    )
  })
}
