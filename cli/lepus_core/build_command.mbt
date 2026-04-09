///|
pub async fn run_build(config : BuildConfig) -> Int {
  let dist_dir = resolve_path(config.cwd, config.dist_dir)
  if @fs.exists(dist_dir) {
    let a = @zipc.Archive::new()
    let root = a.members
    let names = @fs.readdir(dist_dir)
    for name in names {
      let path = resolve_path(dist_dir, name)
      if @fs.kind(path) is Directory {
        
      } else {
        a.add()
      }
    }
    
  }
  0
}
