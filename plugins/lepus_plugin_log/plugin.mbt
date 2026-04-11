///|
pub struct LogEntry {
  level : String
  message : String
} derive(ToJson, FromJson)

///|
let logs : Ref[Array[LogEntry]] = { val: [] }

///|
fn append_log(level : String, message : String) -> LogEntry {
  let entry = { level, message }
  logs.val.push(entry)
  entry
}

///|
fn recent(limit : Int?) -> Array[LogEntry] {
  let n = limit.unwrap_or(20)
  if n <= 0 || logs.val.length() <= n {
    logs.val
  } else {
    let out : Array[LogEntry] = []
    for i = logs.val.length() - n; i < logs.val.length(); i = i + 1 {
      out.push(logs.val[i])
    }
    out
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("log", plugin => {
    plugin.command_sync("info", (payload : String) => {
      append_log("info", payload)
    })
    plugin.command_sync("warn", (payload : String) => {
      append_log("warn", payload)
    })
    plugin.command_sync("error", (payload : String) => {
      append_log("error", payload)
    })
    plugin.command_sync("recent", (payload : Int?) => recent(payload))
    plugin.command_sync("clear", (_ : Json) => {
      logs.val = []
      true
    })
  })
}
