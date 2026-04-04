///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("positioner", fn(context) {
    @lepus_plugin_support.install_rejecting_api(
      context, "example", "Positioner is not supported in Lepus yet.",
    )
  })
}
