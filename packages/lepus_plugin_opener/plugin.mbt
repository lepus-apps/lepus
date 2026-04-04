///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("opener", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){window.open('https://tauri.app','_blank','noopener');return{opened:true,url:'https://tauri.app'}}",
    )
  })
}
