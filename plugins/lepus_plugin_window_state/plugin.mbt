///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("window-state", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){const key='lepus.window-state.example';const state={width:window.innerWidth,height:window.innerHeight};localStorage.setItem(key,JSON.stringify(state));return JSON.parse(localStorage.getItem(key)||'null')}",
    )
  })
}
