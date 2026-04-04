///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("autostart", fn(context) {
    @lepus_plugin_support.install_rejecting_api(
      context, "example", "Autostart is not supported in Lepus yet.",
    )
  })
}
