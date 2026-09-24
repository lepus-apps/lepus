///|
async fn run_setup(config : SetupConfig) -> Int {
  ensure_lepus_toolchain(config.cwd, force=config.force)
}

///|
async fn ensure_lepus_toolchain(cwd : String, force? : Bool = false) -> Int {
  match find_lepus_source_root(cwd) {
    Some(root) => {
      let cc_bin = join_path(root, "_build/native/release/build/cli/cc/cc.exe")
      let lepus_bin = join_path(
        root, "_build/native/release/build/cli/lepus/lepus.exe",
      )
      if !force && @fs.exists(cc_bin) && @fs.exists(lepus_bin) {
        return 0
      }
      println("Preparing Lepus MoonBit toolchain helpers...")
      run_moon_command(root, ["build", "cli/cc", "cli/lepus", "--release"])
    }
    None => {
      println(
        "Cannot find lepus-apps/lepus source. Run `moon add lepus-apps/lepus` first.",
      )
      1
    }
  }
}

///|
async fn find_lepus_source_root(cwd : String) -> String? {
  if is_lepus_source_root(cwd) {
    Some(cwd)
  } else {
    let dep = join_path(cwd, ".mooncakes/lepus-apps/lepus")
    if is_lepus_source_root(dep) {
      Some(dep)
    } else {
      None
    }
  }
}

///|
async fn is_lepus_source_root(path : String) -> Bool {
  @fs.exists(join_path(path, "cli/cc/moon.pkg")) &&
  @fs.exists(join_path(path, "cli/lepus/moon.pkg"))
}
