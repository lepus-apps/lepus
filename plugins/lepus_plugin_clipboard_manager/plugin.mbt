///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("clipboard-manager", plugin => {
    plugin.command("copy", (content : String) => content)
  })
}
