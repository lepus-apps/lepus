///|
async fn walk(
  archive : @zipc.Archive,
  base_path : String,
  current_path : String,
) -> Unit {
  let names = @fs.readdir(current_path)
  for name in names {
    let full_path = resolve_path(current_path, Some(name))
    let relative_path : String = if base_path == current_path {
      name
    } else {
      let base_len = base_path.length() + 1 // +1 for the separator
      full_path[base_len:].to_string()
    }

    if @fs.kind(full_path) is Directory {
      archive.members[relative_path] = @zipc.Member::make(relative_path, Dir)
      walk(archive, base_path, full_path)
    } else {
      let file_data = @fs.read_file(full_path).binary()
      let zip_file = @zipc.deflate_of_bytes(file_data, Default)
      archive.add(
        @zipc.Member::make(relative_path, @zipc.MemberKind::File(zip_file)),
      )
    }
  }
}

///|
pub async fn run_build(config : BuildConfig) -> Int {
  let dist_dir = resolve_path(
    config.cwd,
    Some(config.dist_dir.unwrap_or("dist")),
  )
  if @fs.exists(dist_dir) {
    let archive = @zipc.Archive::new()
    walk(archive, dist_dir, dist_dir)
    @fs.write_file(
      resolve_path(config.cwd, Some("dist.zip")),
      archive.to_bytes(),
      create=0o644,
    )
  }
  0
}
