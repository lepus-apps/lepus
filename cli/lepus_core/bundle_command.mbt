///|
/// Configuration for the `lepus bundle` command.
///
/// Defined in matches.mbt — this is a type alias kept for backward
/// compatibility during refactoring. The canonical definition lives in
/// matches.mbt.

///|
/// Resolved bundle metadata, ready for platform packaging.
priv struct AppBundle {
  app_id : String
  app_name : String
  app_version : String
  platform : String
  bin_path : String
  icon_path : String
  lib_dir : String
  out_dir : String
  verbose : Int
}

///|
/// Derive a default app identifier from the module name in moon.mod.
async fn default_app_id(cwd : String) -> String {
  let mod_path = resolve_path(cwd, Some("moon.mod"))
  if @fs.exists(mod_path) {
    let content = @fs.read_file(mod_path).text()
    let prefix = "name = \""
    match content.find(prefix) {
      Some(start) => {
        let rest = content[start + prefix.length():]
        match rest.find("\"") {
          Some(end) => {
            let module_name = rest[:end].to_owned()
            // Convert "lepus-apps/my-app" → "com.lepus-apps.my-app"
            let dot_name = module_name.replace_all(old="/", new=".")
            "com." + dot_name
          }
          None => "com.lepus.app"
        }
      }
      None => "com.lepus.app"
    }
  } else {
    "com.lepus.app"
  }
}

///|
/// Derive a default app name from the module name.
async fn default_app_name(cwd : String) -> String {
  let mod_path = resolve_path(cwd, Some("moon.mod"))
  if @fs.exists(mod_path) {
    let content = @fs.read_file(mod_path).text()
    let prefix = "name = \""
    match content.find(prefix) {
      Some(start) => {
        let rest = content[start + prefix.length():]
        match rest.find("\"") {
          Some(end) => {
            let module_name = rest[:end].to_owned()
            // "lepus-apps/my-app" → "My App"
            let basename = project_basename(module_name)
            basename.replace_all(old="-", new=" ").to_title_case()
          }
          None => "Lepus App"
        }
      }
      None => "Lepus App"
    }
  } else {
    "Lepus App"
  }
}

///|
/// Capitalize the first letter of each word.
fn String::to_title_case(self : String) -> String {
  let words = self.split(" ")
  words
  .map(word => {
    guard word.length() > 0 else { "" }
    word[0].to_string().to_upper() + word[1:].to_owned()
  })
  .to_array()
  .join(" ")
}

///|
/// Extract the basename of a path (last segment after / or \).
fn path_basename(path : String) -> String {
  let idx = match path.rev_find("/") {
    Some(i) => Some(i)
    None =>
      match path.rev_find("\\") {
        Some(i) => Some(i)
        None => None
      }
  }
  match idx {
    Some(i) => path[i + 1:].to_owned()
    None => path
  }
}

///|
/// Locate the release binary under `_build/native/release/build/`.
/// MoonBit names the binary after the package's last segment, optionally with
/// a platform suffix (e.g. `_macos_arm64`).
async fn find_release_binary(cwd : String) -> String? {
  let build_dir = resolve_path(cwd, Some("_build/native/release/build"))
  if !@fs.exists(build_dir) {
    return None
  }
  let names = @fs.readdir(build_dir)
  // Prefer names that look like an executable (no extension or .exe)
  for name in names {
    let full = resolve_path(build_dir, Some(name))
    if @fs.kind(full) is Regular {
      if name.has_suffix(".exe") ||
        (
          !name.has_suffix(".c") &&
          !name.has_suffix(".o") &&
          !name.has_suffix(".a") &&
          !name.has_suffix(".core") &&
          !name.has_suffix(".mi") &&
          !name.has_suffix(".json") &&
          !name.has_suffix(".moon_db")
        ) {
        return Some(full)
      }
    }
  }
  None
}

///|
/// Find the webview shared library directory relative to the lepus source root
/// inside `.mooncakes/lepus-apps/lepus/`.
async fn find_webview_lib_dir(cwd : String) -> String? {
  let candidates = [
    resolve_path(cwd, Some(".mooncakes/lepus-apps/lepus/webview/lib")),
    resolve_path(cwd, Some(".mooncakes/lepus-apps/webview/lib")),
  ]
  for dir in candidates {
    if @fs.kind(dir) is Directory {
      return Some(dir)
    }
  }
  None
}

///|
/// Copy a single file from src to dst, creating parent directories as needed.
async fn copy_file(src : String, dst : String) -> Unit {
  let parent = lepus_parent_dir(dst)
  match parent {
    Some(p) =>
      if !@fs.exists(p) {
        @fs.mkdir(p, permission=0o755, recursive=true)
      }
    None => ()
  }
  let data = @fs.read_file(src).binary()
  @fs.write_file(dst, data, create_mode=CreateOrTruncate, permission=0o755)
}

///|
/// Same as `parent_dir` from lepus.mbt but available in this package.
fn lepus_parent_dir(path : String) -> String? {
  let path = path.trim_end(chars="/\\").to_owned()
  guard !path.is_empty() else { None }
  match path.rev_find("/") {
    Some(index) => {
      let parent = path[:index].trim_end(chars="/\\").to_owned()
      if parent.is_empty() {
        None
      } else {
        Some(parent)
      }
    }
    None =>
      match path.rev_find("\\") {
        Some(index) => {
          let parent = path[:index].trim_end(chars="/\\").to_owned()
          if parent.is_empty() {
            None
          } else {
            Some(parent)
          }
        }
        None => None
      }
  }
}

///|
pub async fn run_bundle(config : BundleConfig) -> Int {
  let platform = get_platform()
  if !config.skip_build {
    if !config.skip_setup {
      let setup = ensure_lepus_toolchain(config.cwd)
      guard setup == 0 else { return setup }
    }
    let build_args = ["build", "--release"]
    let build = run_moon_command(config.cwd, build_args)
    guard build == 0 else {
      println("Build failed. Run `lepus build --release` first.")
      return build
    }
  }

  // Resolve binary path
  let bin_path = match config.bin {
    Some(p) =>
      if p.has_prefix("/") {
        p
      } else {
        resolve_path(config.cwd, Some(p))
      }
    None =>
      match find_release_binary(config.cwd) {
        Some(p) => p
        None =>
          abort(
            "Cannot find release binary. Run `lepus build --release` first, or specify --bin.",
          )
      }
  }
  if !@fs.exists(bin_path) {
    println("Binary not found: " + bin_path)
    return 1
  }

  // Resolve metadata
  let app_id = match config.app_id {
    Some(id) => id
    None => default_app_id(config.cwd)
  }
  let app_name = match config.app_name {
    Some(name) => name
    None => default_app_name(config.cwd)
  }
  let app_version = match config.app_version {
    Some(v) => v
    None => "1.0.0"
  }

  // Resolve output dir
  let out_dir = match config.out_dir {
    Some(d) => resolve_path(config.cwd, Some(d))
    None => resolve_path(config.cwd, Some("bundle"))
  }

  // Resolve icon
  let icon_path = match config.icon {
    Some(p) =>
      if p.has_prefix("/") {
        p
      } else {
        resolve_path(config.cwd, Some(p))
      }
    None => ""
  }

  // Find webview lib directory
  let lib_dir = match find_webview_lib_dir(config.cwd) {
    Some(d) => d
    None => ""
  }

  let bundle = AppBundle::{
    app_id,
    app_name,
    app_version,
    platform,
    bin_path,
    icon_path,
    lib_dir,
    out_dir,
    verbose: config.verbose,
  }
  ignore(bundle.platform)

  if config.verbose > 0 {
    println("Bundle config:")
    println("  platform:    " + platform)
    println("  app_id:      " + app_id)
    println("  app_name:    " + app_name)
    println("  app_version: " + app_version)
    println("  bin:         " + bin_path)
    println("  icon:        " + icon_path)
    println("  lib_dir:     " + lib_dir)
    println("  out_dir:     " + out_dir)
  }

  match platform {
    "macos" => bundle_macos(bundle)
    "linux" => bundle_linux(bundle)
    "windows" => bundle_windows(bundle)
    _ => {
      println("Bundle is not supported on platform: " + platform)
      1
    }
  }
}

// ── macOS: .app bundle ──────────────────────────────────────────────────────

///|
/// Create a macOS .app bundle directory.
///
/// Layout:
/// ```
/// <out_dir>/<app_name>.app/
///   Contents/
///     Info.plist
///     MacOS/<executable>
///     Frameworks/libwebview.dylib (if found)
///     Resources/<icon>.icns (if provided)
/// ```
async fn bundle_macos(bundle : AppBundle) -> Int {
  let app_dir = resolve_path(bundle.out_dir, Some(bundle.app_name + ".app"))
  let contents_dir = resolve_path(app_dir, Some("Contents"))
  let macos_dir = resolve_path(contents_dir, Some("MacOS"))
  let frameworks_dir = resolve_path(contents_dir, Some("Frameworks"))
  let resources_dir = resolve_path(contents_dir, Some("Resources"))

  // Create directory structure
  for dir in [macos_dir, frameworks_dir, resources_dir] {
    if !@fs.exists(dir) {
      @fs.mkdir(dir, permission=0o755, recursive=true)
    }
  }

  // Copy binary into MacOS/
  let exe_name = path_basename(bundle.bin_path)
  let dest_bin = resolve_path(macos_dir, Some(exe_name))
  copy_file(bundle.bin_path, dest_bin)

  // Copy webview shared library into Frameworks/
  if bundle.lib_dir != "" {
    let lib_names = @fs.readdir(bundle.lib_dir)
    for name in lib_names {
      if name.has_suffix(".dylib") {
        let src = resolve_path(bundle.lib_dir, Some(name))
        let dst = resolve_path(frameworks_dir, Some(name))
        copy_file(src, dst)
        if bundle.verbose > 0 {
          println("  copied lib: " + name)
        }
      }
    }
  }

  // Copy icon into Resources/
  let icon_base = if bundle.icon_path != "" && @fs.exists(bundle.icon_path) {
    let base = path_basename(bundle.icon_path)
    let dest_icon = resolve_path(resources_dir, Some(base))
    copy_file(bundle.icon_path, dest_icon)
    base
  } else {
    ""
  }

  // Generate Info.plist
  // Strip extension for CFBundleIconFile
  let icon_for_plist = if icon_base != "" {
    match icon_base.rev_find(".") {
      Some(i) => icon_base[:i].to_owned()
      None => icon_base
    }
  } else {
    ""
  }
  let plist = generate_info_plist(bundle, icon_for_plist)
  let plist_path = resolve_path(contents_dir, Some("Info.plist"))
  @fs.write_file(
    plist_path,
    @encoding/utf8.encode(plist),
    create_mode=CreateOrTruncate,
    permission=0o644,
  )

  println("Created macOS bundle: " + app_dir)
  0
}

///|
fn generate_info_plist(bundle : AppBundle, icon_for_plist : String) -> String {
  let icon_entry = if icon_for_plist != "" {
    "    <key>CFBundleIconFile</key>\n    <string>" +
    icon_for_plist +
    "</string>\n"
  } else {
    ""
  }
  (
    $|<?xml version="1.0" encoding="UTF-8"?>
    $|<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    $|<plist version="1.0">
    $|<dict>
    $|    <key>CFBundleDevelopmentRegion</key>
    $|    <string>en</string>
    $|    <key>CFBundleExecutable</key>
    $|    <string>\{bundle.app_name}</string>
    $|    <key>CFBundleIdentifier</key>
    $|    <string>\{bundle.app_id}</string>
    $|    <key>CFBundleName</key>
    $|    <string>\{bundle.app_name}</string>
    $|    <key>CFBundleDisplayName</key>
    $|    <string>\{bundle.app_name}</string>
    $|    <key>CFBundleVersion</key>
    $|    <string>\{bundle.app_version}</string>
    $|    <key>CFBundleShortVersionString</key>
    $|    <string>\{bundle.app_version}</string>
    $|    <key>CFBundlePackageType</key>
    $|    <string>APPL</string>
    $|    <key>CFBundleInfoDictionaryVersion</key>
    $|    <string>6.0</string>
    $|    <key>LSMinimumSystemVersion</key>
    $|    <string>10.13</string>
    $|    <key>NSHighResolutionCapable</key>
    $|    <true/>
    $|    <key>LSUIElement</key>
    $|    <false/>
    $|\{icon_entry}</dict>
    $|</plist>
  )
}

// ── Linux: directory bundle with .desktop entry ─────────────────────────────

///|
/// Create a Linux application directory bundle with a .desktop entry.
///
/// Layout:
/// ```
/// <out_dir>/<app_name>/
///   bin/<executable>
///   lib/libwebview.so (if found)
///   share/
///     icons/<icon>.png (if provided)
///     applications/<app_id>.desktop
/// ```
async fn bundle_linux(bundle : AppBundle) -> Int {
  let app_dir = resolve_path(bundle.out_dir, Some(bundle.app_name))
  let bin_dir = resolve_path(app_dir, Some("bin"))
  let lib_dir = resolve_path(app_dir, Some("lib"))
  let share_dir = resolve_path(app_dir, Some("share"))
  let icons_dir = resolve_path(share_dir, Some("icons"))
  let applications_dir = resolve_path(share_dir, Some("applications"))

  for dir in [bin_dir, lib_dir, icons_dir, applications_dir] {
    if !@fs.exists(dir) {
      @fs.mkdir(dir, permission=0o755, recursive=true)
    }
  }

  // Copy binary
  let exe_name = path_basename(bundle.bin_path)
  let dest_bin = resolve_path(bin_dir, Some(exe_name))
  copy_file(bundle.bin_path, dest_bin)

  // Copy webview shared library
  if bundle.lib_dir != "" {
    let lib_names = @fs.readdir(bundle.lib_dir)
    for name in lib_names {
      if name.has_suffix(".so") || name.contains(".so.") {
        let src = resolve_path(bundle.lib_dir, Some(name))
        let dst = resolve_path(lib_dir, Some(name))
        copy_file(src, dst)
        if bundle.verbose > 0 {
          println("  copied lib: " + name)
        }
      }
    }
  }

  // Copy icon
  let icon_basename = if bundle.icon_path != "" && @fs.exists(bundle.icon_path) {
    let base = path_basename(bundle.icon_path)
    let dest_icon = resolve_path(icons_dir, Some(base))
    copy_file(bundle.icon_path, dest_icon)
    base
  } else {
    ""
  }

  // Generate .desktop entry
  let desktop = generate_desktop_entry(bundle, icon_basename)
  let desktop_path = resolve_path(
    applications_dir,
    Some(bundle.app_id + ".desktop"),
  )
  @fs.write_file(
    desktop_path,
    @encoding/utf8.encode(desktop),
    create_mode=CreateOrTruncate,
    permission=0o755,
  )

  println("Created Linux bundle: " + app_dir)
  0
}

///|
fn generate_desktop_entry(bundle : AppBundle, icon_name : String) -> String {
  (
    $|[Desktop Entry]
    $|Type=Application
    $|Name=\{bundle.app_name}
    $|Exec=bin/\{bundle.app_name}
    $|\{if icon_name != "" { "Icon=" + bundle.app_name } else { "" }}
    $|Categories=Utility;
    $|Terminal=false
    $|StartupWMClass=\{bundle.app_id}
  )
}

// ── Windows: directory bundle ────────────────────────────────────────────────

///|
/// Create a Windows application directory bundle.
///
/// Layout:
/// ```
/// <out_dir>/<app_name>/
///   <executable>.exe
///   webview.dll (if found)
///   <icon>.ico (if provided)
/// ```
async fn bundle_windows(bundle : AppBundle) -> Int {
  let app_dir = resolve_path(bundle.out_dir, Some(bundle.app_name))
  if !@fs.exists(app_dir) {
    @fs.mkdir(app_dir, permission=0o755, recursive=true)
  }

  // Copy binary
  let exe_name = path_basename(bundle.bin_path)
  let dest_bin = resolve_path(app_dir, Some(exe_name))
  copy_file(bundle.bin_path, dest_bin)

  // Copy webview.dll
  if bundle.lib_dir != "" {
    let lib_names = @fs.readdir(bundle.lib_dir)
    for name in lib_names {
      if name.has_suffix(".dll") {
        let src = resolve_path(bundle.lib_dir, Some(name))
        let dst = resolve_path(app_dir, Some(name))
        copy_file(src, dst)
        if bundle.verbose > 0 {
          println("  copied lib: " + name)
        }
      }
    }
  }

  // Copy icon
  if bundle.icon_path != "" && @fs.exists(bundle.icon_path) {
    let icon_name = path_basename(bundle.icon_path)
    let dest_icon = resolve_path(app_dir, Some(icon_name))
    copy_file(bundle.icon_path, dest_icon)
  }

  println("Created Windows bundle: " + app_dir)
  0
}
