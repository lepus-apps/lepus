///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("single_instance", _ => ())
}
