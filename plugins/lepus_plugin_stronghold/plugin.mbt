///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("stronghold", fn(context) {
    @lepus_plugin_support.install_rejecting_api(
      context, "example", "Stronghold is not supported in Lepus yet.",
    )
  })
}
