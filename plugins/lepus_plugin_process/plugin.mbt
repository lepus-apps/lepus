///|
pub struct ProcessRunRequest {
  program : String
  args : Array[String]
} derive(ToJson, FromJson)

///|
pub struct ProcessRunReply {
  exit_code : Int
  output : String
} derive(ToJson, FromJson)

///|
async fn run_capture(payload : ProcessRunRequest) -> ProcessRunReply {
  let (stdout_r, stdout_w) = @pipe.pipe()
  defer stdout_r.close()
  let exit_code = @process.run(payload.program, payload.args, stdout=stdout_w)
  stdout_w.close()
  { exit_code, output: stdout_r.read_all().text() }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("process", plugin => {
    plugin.command("run", (payload : ProcessRunRequest) => run_capture(payload))
  })
}
