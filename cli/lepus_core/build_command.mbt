///|
pub async fn run_build(config : BuildConfig) -> Int {
  let frontend_dir = resolve_path(config.cwd, config.frontend_dir)
  if @fs.exists(join_path(frontend_dir, "package.json")) {
    let npm_ready = ensure_npm_ready(frontend_dir)
    guard npm_ready == 0 else { return npm_ready }

    let npm_exit = @process.run(
      npm_command(),
      ["run", "build"],
      cwd=frontend_dir,
    )
    guard npm_exit == 0 else {
      println("`npm run build` failed with exit code " + npm_exit.to_string())
      return npm_exit
    }

    let dist_html = join_path(join_path(frontend_dir, "dist"), "index.html")
    guard @fs.exists(dist_html) else {
      println("Missing Vite build output: " + dist_html)
      return 1
    }

    let output = join_path(config.cwd, "index.mbt")
    guard write_embed_module_file(dist_html, output) else {
      println("Failed to write embedded frontend module: " + output)
      return 1
    }
  }

  let moon_args = match config.out_dir {
    Some(out_dir) => ["build", "--target", "native", "main.mbt", "-C", out_dir]
    None => ["build", "--target", "native", "main.mbt"]
  }
  let exit_code = run_moon_command(config.cwd, moon_args)
  if exit_code != 0 {
    println("Moon build failed with exit code " + exit_code.to_string())
  }
  exit_code
}

///|
async fn write_embed_module_file(
  input_path : String,
  output_path : String,
) -> Bool {
  let content = @fs.read_file(input_path).text() catch { _ => return false }
  @fs.write_file(output_path, embed_module_source(content))
  true
}
