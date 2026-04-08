///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("global-shortcut", _ => ())
}
