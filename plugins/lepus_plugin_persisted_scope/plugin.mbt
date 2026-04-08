///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("persisted-scope", _ => ())
}
