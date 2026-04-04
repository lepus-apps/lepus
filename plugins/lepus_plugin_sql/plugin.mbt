///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("sql", fn(context) {
    @lepus_plugin_support.install_rejecting_api(
      context, "example", "SQL is not supported in Lepus yet.",
    )
  })
}
