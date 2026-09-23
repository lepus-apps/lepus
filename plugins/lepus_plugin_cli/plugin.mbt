///|
pub struct CliInfo {
  argv : Array[String]
  cwd : String
} derive(ToJson, FromJson)

///|
pub fn info() -> CliInfo {
  { argv: @env.args(), cwd: ".", }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin("cli", plugin => {
    plugin.command_sync("args", (_ : Json) => @env.args())
    plugin.command_sync("cwd", (_ : Json) => ".")
    plugin.command_sync("info", (_ : Json) => info())
  })
}
