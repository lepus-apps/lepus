///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("updater", fn(context) {
    @lepus_plugin_support.install_rejecting_api(
      context, "example", "Updater is not supported in Lepus yet.",
    )
  })
}
