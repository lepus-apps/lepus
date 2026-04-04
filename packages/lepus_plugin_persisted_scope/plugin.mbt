///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("persisted-scope", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){const key='lepus.scope.example';const scopes=['app','cache','data'];localStorage.setItem(key,JSON.stringify(scopes));const restored=JSON.parse(localStorage.getItem(key)||'[]');return{scopes:restored}}",
    )
  })
}
