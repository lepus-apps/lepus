///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("persisted_scope", _ => ())
}
