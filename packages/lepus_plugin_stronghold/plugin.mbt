///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("stronghold", fn(context) {
    @lepus_plugin_support.install_rejecting_api(
      context, "example", "Stronghold is not supported in Lepus yet.",
    )
  })
}
