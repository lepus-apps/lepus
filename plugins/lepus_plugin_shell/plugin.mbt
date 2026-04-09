///|
struct ExecParams {
  cmd : StringView
  args : Array[String]
  input_data : String?
} derive(ToJson, FromJson)

///|
struct ExecResult {
  exit_code : Int
  output : String
} derive(ToJson, FromJson)

///|
async fn execute_script_with_output(
  program : String,
  args : Array[String],
  input_data : String,
) -> ExecResult {
  // Create a pipe for stdin if we have input data
  let (stdin_r, stdin_w) = @pipe.pipe()
  let (stdout_r, stdout_w) = @pipe.pipe()
  // Write input data to stdin pipe
  if input_data.length() > 0 {
    stdin_w.write(@utf8.encode(input_data))
  }
  stdin_w.close()
  defer stdout_r.close()
  defer stdin_r.close()

  // Execute and capture output directly
  let exit_code = @process.run(program, args, stdin=stdin_r, stdout=stdout_w)
  stdout_w.close()
  { exit_code, output: stdout_r.read_all().text() }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("shell", plugin => {
    plugin.command("exec", (payload : ExecParams) => {
      execute_script_with_output(
        payload.cmd.to_string(),
        payload.args,
        payload.input_data.unwrap_or(""),
      )
    })
  })
}
