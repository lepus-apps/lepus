///|
pub async fn run_dev(config : DevConfig) -> Int {
  let frontend_dir = resolve_path(config.cwd, config.frontend_dir)
  if !@fs.exists(join_path(frontend_dir, "package.json")) {
    return run_moon_command(config.cwd, [
      "run", "--target", "native", "main.mbt",
    ])
  }

  let npm_ready = ensure_npm_ready(frontend_dir)
  guard npm_ready == 0 else { return npm_ready }

  let host = config.host.unwrap_or("127.0.0.1")
  let port = config.port.unwrap_or(1420)
  let dev_url = "http://" + host + ":" + port.to_string()
  let npm = npm_command()

  println("Starting Vite dev server at " + dev_url)
  @async.with_task_group(group => {
    let vite = @process.spawn(
      group,
      npm,
      [
        "run",
        "dev",
        "--",
        "--host",
        host,
        "--port",
        port.to_string(),
        "--strictPort",
      ],
      cwd=frontend_dir,
      no_wait=true,
    )
    @async.sleep(1500)
    let exit_code = run_moon_command(
      config.cwd,
      ["run", "--target", "native", "main.mbt"],
      extra_env={ "LEPUS_DEV_URL": dev_url },
    )
    vite.cancel()
    ignore(vite.wait() catch { _ => 0 })
    exit_code
  })
}
