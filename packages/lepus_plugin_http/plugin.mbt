///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("http", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){const response=await fetch('data:application/json,%7B%22ok%22%3Atrue%2C%22plugin%22%3A%22http%22%7D');return await response.json()}",
    )
  })
}
