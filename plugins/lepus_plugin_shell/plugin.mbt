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
  let (stdout_r, stdout_w) = @process.read_from_process(shared=true) catch {
    _ => return { exit_code: 1, output: "", }
  }
  defer stdout_r.close()
  let (stdin_r, stdin_w) = @process.write_to_process() catch {
    _ => return { exit_code: 1, output: "", }
  }
  // Write input data to stdin pipe
  if input_data.length() > 0 {
    stdin_w.write(input_data)
  }
  stdin_w.close()

  // Execute and capture output directly
  let exit_code = @process.run(program, args, stdin=stdin_r, stdout=stdout_w)
  stdout_w.close()
  { exit_code, output: stdout_r.read_all().text(), } catch {
    _ => { exit_code, output: "", }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin("shell", plugin => {
    plugin.command("exec", (payload : ExecParams) => {
      execute_script_with_output(
        payload.cmd.to_owned(),
        payload.args,
        payload.input_data.unwrap_or(""),
      )
    })
  })
}
