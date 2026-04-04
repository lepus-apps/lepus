///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("sql", fn(context) {
    @lepus_plugin_support.install_rejecting_api(
      context, "example", "SQL is not supported in Lepus yet.",
    )
  })
}
