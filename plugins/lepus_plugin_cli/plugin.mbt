///|
pub struct CliInfo {
  argv : Array[String]
  cwd : String
} derive(ToJson, FromJson)

///|
pub fn info() -> CliInfo {
  { argv: @sys.get_cli_args(), cwd: "." }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("cli", plugin => {
    plugin.command_sync("args", (_ : Json) => @sys.get_cli_args())
    plugin.command_sync("cwd", (_ : Json) => ".")
    plugin.command_sync("info", (_ : Json) => info())
  })
}
