///|
struct SumPayload {
  left : Int
  right : Int
} derive(ToJson, FromJson)

///|
struct SumReply {
  total : Int
} derive(ToJson, FromJson)

///|
async fn sum_async_handler(payload : SumPayload) -> SumReply {
  @async.sleep(1000)
  { total: payload.left + payload.right }
}

///|
async fn main {
  let root_dir = @fs.realpath("example")

  let window = @webview.Window::new(
    title="title",
    width=800,
    height=600,
    frameless=true,
    url="lepus://localhost/index.html",
    title_bar_style=Hidden,
    title_bar_overlay=true,
    devtools=true,
    debug=1,
  )
  window.install(
    @webview.Plugin::new("math", plugin => {
      plugin.command("sum", (payload : SumPayload) => SumReply::{
        total: payload.left + payload.right,
      })
      plugin.command("sum_async", sum_async_handler)
    }),
  )
  window.install(
    @webview.Plugin::new("console", plugin => {
      plugin.command("log", (payload : Json) => {
        println("[child-console:log] \{payload.stringify()}")
        payload
      })
      plugin.command("error", (payload : Json) => {
        println("[child-console:error] \{payload.stringify()}")
        payload
      })
    }),
  )
  window.set_custom_protocol("lepus", root_dir)
  window.run()
}

///|
async test {
  let payload = SumPayload::{ left: 2, right: 3 }
  json_inspect(sum_async_handler(payload), content={ "total": 5 })
}
