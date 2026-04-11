///|
pub struct OsInfo {
  os : String
  arch : String
} derive(ToJson, FromJson)

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("os", plugin => {
    plugin.command_sync("os", (_ : Json) => os_name())
    plugin.command_sync("arch", (_ : Json) => arch_name())
    plugin.command_sync("info", (_ : Json) => {
      os: os_name(),
      arch: arch_name(),
    })
  })
}
