///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("localhost", fn(context) {
    @lepus_plugin_support.install_rejecting_api(
      context, "example", "Localhost is not supported in Lepus yet.",
    )
  })
}
