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
  let out_dir = resolve_path(
    config.cwd,
    Some(config.output_dir.unwrap_or("_build")),
  )
  if !@fs.exists(out_dir) {
    @fs.mkdir(out_dir, permission=0o755, recursive=true)
  }

  if @fs.exists(dist_dir) {
    let archive = @zipc.Archive::new()
    walk(archive, dist_dir, dist_dir)
    @fs.write_file(
      join_path(out_dir, "dist.zip"),
      archive.to_bytes(),
      create=0o644,
      truncate=true,
    )
  }

  match mobile_target(config.target) {
    Some(target) => write_mobile_package(config, out_dir, target)
    None => ()
  }
  0
}

///|
fn mobile_target(target : String) -> String? {
  if target == "android" || target == "ios" {
    Some(target)
  } else {
    None
  }
}

///|
async fn write_mobile_package(
  config : BuildConfig,
  out_dir : String,
  target : String,
) -> Unit {
  let mobile_dir = join_path(out_dir, target)
  if !@fs.exists(mobile_dir) {
    @fs.mkdir(mobile_dir, permission=0o755, recursive=true)
  }
  @fs.write_file(
    join_path(mobile_dir, "lepus_mobile.json"),
    mobile_manifest(config, target),
    create=0o644,
    truncate=true,
  )
  @fs.write_file(
    join_path(mobile_dir, "lepus_mobile.h"),
    mobile_header(target),
    create=0o644,
    truncate=true,
  )
  @fs.write_file(
    join_path(mobile_dir, "lepus_mobile.c"),
    mobile_c_source(target),
    create=0o644,
    truncate=true,
  )
  @fs.write_file(
    join_path(mobile_dir, "README.md"),
    mobile_readme(target),
    create=0o644,
    truncate=true,
  )
}

///|
fn mobile_manifest(config : BuildConfig, target : String) -> String {
  (
    #|{
    #|  "name": "
  ) + project_basename(config.cwd) + (
    #|",
    #|  "target": "
  ) + target + (
    #|",
    #|  "distArchive": "../dist.zip",
    #|  "library": "liblepus.a",
    #|  "header": "lepus_mobile.h",
    #|  "adapter": "lepus_mobile.c"
    #|}
  )
}

///|
fn mobile_header(target : String) -> String {
  (
    #|#ifndef LEPUS_MOBILE_H
    #|#define LEPUS_MOBILE_H
    #|
    #|#ifdef __cplusplus
    #|extern "C" {
    #|#endif
    #|
    #|const char *lepus_mobile_target(void);
    #|const unsigned char *lepus_mobile_dist_zip(unsigned int *len);
    #|
    #|#ifdef __cplusplus
    #|}
    #|#endif
    #|
    #|#endif
    #|
    #|/* Generated for
  ) + " " + target + " hosts. */\n"
}

///|
fn mobile_c_source(target : String) -> String {
  (
    #|#include "lepus_mobile.h"
    #|
    #|const char *lepus_mobile_target(void) {
    #|  return "
  ) + target + (
    #|";
    #|}
    #|
    #|const unsigned char *lepus_mobile_dist_zip(unsigned int *len) {
    #|  if (len != 0) {
    #|    *len = 0;
    #|  }
    #|  return 0;
    #|}
  )
}

///|
fn mobile_readme(target : String) -> String {
  if target == "ios" {
    (
      #|# Lepus iOS host package
      #|
      #|Build the MoonBit native library for an iOS target, copy `liblepus.a` next to this folder, and add `lepus_mobile.h` to your Xcode project.
      #|
      #|The host app should render the bundled frontend with `WKWebView` and call the exported Lepus C ABI for native services.
      #|
      #|This mirrors zero-native's iOS embedding model: a thin Swift host links a static native library and owns the platform WebView.
      #|
    )
  } else {
    (
      #|# Lepus Android host package
      #|
      #|Build the MoonBit native library for an Android target, copy `liblepus.a` into your Android `cpp/lib` directory, and include `lepus_mobile.h` from your JNI bridge.
      #|
      #|The host app should render the bundled frontend with Android WebView and forward JNI calls to the exported Lepus C ABI.
      #|
      #|This mirrors zero-native's Android embedding model: a thin Kotlin/Java host links a native static library through JNI and owns the platform WebView.
      #|
    )
  }
}
