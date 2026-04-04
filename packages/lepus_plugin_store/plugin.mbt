///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("store", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){const key='lepus.store.example';localStorage.setItem(key,JSON.stringify({ok:true,plugin:'store'}));const value=JSON.parse(localStorage.getItem(key)||'null');localStorage.removeItem(key);return value}",
    )
  })
}
