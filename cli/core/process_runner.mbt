///|
pub fn npm_command() -> String {
  if get_platform() == "windows" {
    "npm.cmd"
  } else {
    "npm"
  }
}

///|
fn executable_name(name : String) -> String {
  if get_platform() == "windows" {
    name + ".cmd"
  } else {
    name
  }
}

///|
async fn local_bin(frontend_dir : String, name : String) -> String {
  let path = join_path(
    join_path(join_path(frontend_dir, "node_modules"), ".bin"),
    executable_name(name),
  )
  if @fs.exists(path) {
    path
  } else {
    executable_name(name)
  }
}

///|
pub async fn ensure_npm_ready(frontend_dir : String) -> Int {
  let package_manager = frontend_package_manager(frontend_dir)
  guard has_command(package_manager) else {
    println("Missing frontend package manager: " + package_manager)
    return 1
  }
  if @fs.kind(join_path(frontend_dir, "node_modules")) is Directory {
    return 0
  }
  println("Installing frontend dependencies with " + package_manager + "...")
  let exit_code = @process.run(package_manager, ["install"], cwd=frontend_dir)
  if exit_code != 0 {
    println(
      "`" +
      package_manager +
      " install` failed with exit code " +
      exit_code.to_string(),
    )
  }
  exit_code
}

///|
async fn frontend_package_manager(frontend_dir : String) -> String {
  if @fs.exists(join_path(frontend_dir, "bun.lock")) && has_command("bun") {
    "bun"
  } else if @fs.exists(join_path(frontend_dir, "pnpm-lock.yaml")) &&
    has_command(executable_name("pnpm")) {
    executable_name("pnpm")
  } else if @fs.exists(join_path(frontend_dir, "yarn.lock")) &&
    has_command(executable_name("yarn")) {
    executable_name("yarn")
  } else {
    npm_command()
  }
}

///|
async fn run_frontend_tool(
  frontend_dir : String,
  name : String,
  args : Array[String],
) -> Int {
  let command = local_bin(frontend_dir, name)
  let display = if args.length() == 0 {
    name
  } else {
    name + " " + args.join(" ")
  }
  println("Running " + display)
  let exit_code = @process.run(command, args, cwd=frontend_dir)
  if exit_code != 0 {
    println("`" + name + "` failed with exit code " + exit_code.to_string())
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
