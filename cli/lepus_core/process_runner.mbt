///|
pub fn npm_command() -> String {
  if get_platform() == "windows" {
    "npm.cmd"
  } else {
    "npm"
  }
}

///|
pub async fn ensure_npm_ready(frontend_dir : String) -> Int {
  let npm = npm_command()
  guard has_command(npm) else {
    println("Missing npm executable: " + npm)
    return 1
  }
  if is_directory(join_path(frontend_dir, "node_modules")) {
    return 0
  }
  println("Installing frontend dependencies with npm...")
  let exit_code = @process.run(npm, ["install"], cwd=frontend_dir)
  if exit_code != 0 {
    println("`npm install` failed with exit code " + exit_code.to_string())
  }
  exit_code
}

///|
pub async fn run_moon_command(
  cwd : String,
  args : Array[String],
  extra_env? : Map[String, String] = {},
) -> Int {
  guard has_command("moon") else {
    println("Missing moon executable in PATH")
    return 1
  }
  @process.run("moon", args, cwd~, extra_env~)
}
