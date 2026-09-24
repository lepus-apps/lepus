///|
async fn walk(
  archive : @zipc.Archive,
  base_path : String,
  current_path : String,
) -> @zipc.Archive {
  let names = @fs.readdir(current_path)
  let mut acc = archive
  for name in names {
    let full_path = resolve_path(current_path, Some(name))
    let relative_path : String = if base_path == current_path {
      name
    } else {
      let base_len = base_path.length() + 1 // +1 for the separator
      full_path[base_len:].to_owned()
    }

    if @fs.kind(full_path) is Directory {
      let next = acc.add(@zipc.Member::make(relative_path, Dir))
      acc = walk(next, base_path, full_path)
    } else {
      let file_data = @fs.read_file(full_path).binary()
      let zip_file = @zipc.File::deflate_from_bytes(file_data)
      acc = acc.add(@zipc.Member::make(relative_path, File(zip_file)))
    }
  }
  acc
}

///|
pub async fn run_build(config : BuildConfig) -> Int {
  if !config.skip_setup {
    let setup = ensure_lepus_toolchain(config.cwd)
    guard setup == 0 else { return setup }
  }

  let frontend_dir = resolve_path(config.cwd, config.frontend_dir)
  if !config.skip_frontend &&
    @fs.exists(join_path(frontend_dir, "package.json")) {
    let frontend = run_frontend_build(config, frontend_dir)
    guard frontend == 0 else { return frontend }
  }

  let dist_dir = resolve_path(
    frontend_dir,
    Some(config.dist_dir.unwrap_or("dist")),
  )
  if @fs.exists(dist_dir) {
    try {
      let archive = @zipc.Archive::empty()
      let archive = walk(archive, dist_dir, dist_dir)
      let _build_dir = resolve_path(
        config.cwd,
        Some(config.output_dir.unwrap_or("_build")),
      )
      if !@fs.exists(_build_dir) {
        @fs.mkdir(_build_dir, permission=0o755)
      }

      @fs.write_file(
        join_path(_build_dir, "dist.zip"),
        archive.to_bytes(),
        create_mode=CreateOrTruncate,
        permission=0o644,
      )
    } catch {
      err => {
        println("Failed to build dist.zip: \{err}")
        return 1
      }
    }
  }

  if config.skip_moon {
    0
  } else {
    run_moon_app_build(config)
  }
}

///|
async fn run_frontend_build(config : BuildConfig, frontend_dir : String) -> Int {
  let npm_ready = ensure_npm_ready(frontend_dir)
  guard npm_ready == 0 else { return npm_ready }

  if config.typecheck && @fs.exists(join_path(frontend_dir, "tsconfig.json")) {
    let typecheck = run_frontend_tool(frontend_dir, "tsc", [])
    guard typecheck == 0 else { return typecheck }
  }
  run_frontend_tool(frontend_dir, "vite", ["build"])
}

///|
async fn run_moon_app_build(config : BuildConfig) -> Int {
  let args = if config.release { ["build", "--release"] } else { ["build"] }
  run_moon_command(config.cwd, args)
}
