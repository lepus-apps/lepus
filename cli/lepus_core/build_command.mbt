///|
pub async fn run_build(config : BuildConfig) -> Int {
  let frontend_dir = resolve_path(config.cwd, config.frontend_dir)
  let target_dir = resolve_target_dir(config)
  let staging_project_dir = build_staging_project_dir(config.cwd)
  let frontend_dist_dir = build_frontend_dist_dir(config.cwd)
  if @fs.exists(join_path(frontend_dir, "package.json")) {
    let npm_ready = ensure_npm_ready(frontend_dir)
    guard npm_ready == 0 else { return npm_ready }

    let npm_exit = @process.run(
      npm_command(),
      ["run", "build", "--", "--outDir", frontend_dist_dir],
      cwd=frontend_dir,
    )
    guard npm_exit == 0 else {
      println("`npm run build` failed with exit code " + npm_exit.to_string())
      return npm_exit
    }

    let embed_exit = @process.run(
      "node",
      [
        "-e",
        stage_project_script(),
        config.cwd,
        frontend_dist_dir,
        staging_project_dir,
      ],
      cwd=frontend_dir,
    )
    guard embed_exit == 0 else {
      println("Failed to prepare build staging project")
      return embed_exit
    }

    let moon_exit = run_moon_command(staging_project_dir, [
      "build", "--release", "--target", "native", "main.mbt", "--target-dir", target_dir,
    ])
    if moon_exit != 0 {
      println("Moon build failed with exit code " + moon_exit.to_string())
      return moon_exit
    }
    return bundle_runtime_dependencies(config.cwd, target_dir)
  }

  let moon_args = [
    "build", "--release", "--target", "native", "main.mbt", "--target-dir", target_dir,
  ]
  let exit_code = run_moon_command(config.cwd, moon_args)
  if exit_code != 0 {
    println("Moon build failed with exit code " + exit_code.to_string())
    return exit_code
  }
  bundle_runtime_dependencies(config.cwd, target_dir)
}

///|
fn resolve_target_dir(config : BuildConfig) -> String {
  match config.out_dir {
    Some(out_dir) => resolve_path(config.cwd, Some(out_dir))
    None => join_path(config.cwd, "_build")
  }
}

///|
fn build_staging_root(project_root : String) -> String {
  join_path(join_path(project_root, "_build"), "lepus-build")
}

///|
fn build_staging_project_dir(project_root : String) -> String {
  join_path(build_staging_root(project_root), "project")
}

///|
fn build_frontend_dist_dir(project_root : String) -> String {
  join_path(build_staging_root(project_root), "dist")
}

///|
fn native_build_dir(target_dir : String) -> String {
  join_path(join_path(join_path(target_dir, "native"), "release"), "build")
}

///|
fn built_executable_path(project_root : String, target_dir : String) -> String {
  join_path(
    native_build_dir(target_dir),
    project_basename(project_root) + ".exe",
  )
}

///|
async fn bundle_runtime_dependencies(
  project_root : String,
  target_dir : String,
) -> Int {
  let platform = get_platform()
  if platform == "windows" {
    return copy_runtime_file(
      join_path(
        join_path(project_root, ".mooncakes/lepus-apps/webview/lib"),
        "webview.dll",
      ),
      join_path(native_build_dir(target_dir), "webview.dll"),
    )
  }
  if platform == "macos" {
    let output_dir = native_build_dir(target_dir)
    let dylib_name = "libwebview.0.12.dylib"
    let copy_exit = copy_runtime_file(
      join_path(
        join_path(project_root, ".mooncakes/lepus-apps/webview/lib"),
        dylib_name,
      ),
      join_path(output_dir, dylib_name),
    )
    guard copy_exit == 0 else { return copy_exit }
    return ensure_macos_runtime_rpath(
      built_executable_path(project_root, target_dir),
      "@executable_path",
    )
  }
  0
}

///|
async fn copy_runtime_file(source : String, target : String) -> Int {
  if !@fs.exists(source) {
    println("Missing runtime dependency: " + source)
    return 1
  }
  let output_dir = parent_dir(target)
  if !@fs.exists(output_dir) {
    @fs.mkdir(output_dir, permission=0o755, recursive=true)
  }
  @fs.write_file(target, @fs.read_file(source), create=0o755, truncate=true)
  0
}

///|
async fn ensure_macos_runtime_rpath(executable : String, rpath : String) -> Int {
  guard has_command("install_name_tool") else {
    println("Missing install_name_tool; cannot fix macOS runtime search path")
    return 1
  }
  if executable_has_rpath(executable, rpath) {
    return 0
  }
  let legacy_rpath = ".mooncakes/lepus-apps/webview/lib"
  if executable_has_rpath(executable, legacy_rpath) {
    let replace_exit = @process.run("install_name_tool", [
      "-rpath", legacy_rpath, rpath, executable,
    ])
    if replace_exit != 0 {
      println("Failed to update executable rpath for " + executable)
    }
    return replace_exit
  }
  let add_exit = @process.run("install_name_tool", [
    "-add_rpath", rpath, executable,
  ])
  if add_exit != 0 {
    println("Failed to add executable rpath for " + executable)
  }
  add_exit
}

///|
async fn executable_has_rpath(executable : String, rpath : String) -> Bool {
  @process.run("sh", [
    "-lc", "otool -l \"$1\" | grep -Fq \"path $2\"", "_", executable, rpath,
  ]) ==
  0
}

///|
fn parent_dir(path : String) -> String {
  match path.rev_find("/") {
    Some(index) => path[:index].to_string()
    None => "."
  }
}

///|
fn stage_project_script() -> String {
  (
    #|const fs = require("node:fs");
    #|const path = require("node:path");
    #|
    #|const projectRoot = path.resolve(process.argv[1]);
    #|const distDir = path.resolve(process.argv[2]);
    #|const stagingDir = path.resolve(process.argv[3]);
    #|const distBaseDir = path.dirname(distDir);
    #|const outputFile = path.join(stagingDir, "frontend_url.mbt");
    #|const entries = [];
    #|
    #|const excludedNames = new Set([
    #|  "_build",
    #|  ".mooncakes",
    #|  "node_modules",
    #|  "dist",
    #|  ".git",
    #|  ".DS_Store",
    #|  "embedded_dist.mbt",
    #|]);
    #|
    #|function ensureDir(dir) {
    #|  fs.mkdirSync(dir, { recursive: true });
    #|}
    #|
    #|function copyProject(sourceDir, targetDir) {
    #|  ensureDir(targetDir);
    #|  for (const name of fs.readdirSync(sourceDir)) {
    #|    if (excludedNames.has(name)) continue;
    #|    const sourcePath = path.join(sourceDir, name);
    #|    const targetPath = path.join(targetDir, name);
    #|    const stat = fs.lstatSync(sourcePath);
    #|    if (stat.isDirectory()) {
    #|      copyProject(sourcePath, targetPath);
    #|      continue;
    #|    }
    #|    if (stat.isSymbolicLink()) {
    #|      const linkTarget = fs.readlinkSync(sourcePath);
    #|      fs.symlinkSync(linkTarget, targetPath);
    #|      continue;
    #|    }
    #|    fs.copyFileSync(sourcePath, targetPath);
    #|  }
    #|}
    #|
    #|function linkMooncakes() {
    #|  const source = path.join(projectRoot, ".mooncakes");
    #|  if (!fs.existsSync(source)) return;
    #|  const target = path.join(stagingDir, ".mooncakes");
    #|  const relative = path.relative(path.dirname(target), source) || ".";
    #|  fs.symlinkSync(relative, target, process.platform === "win32" ? "junction" : "dir");
    #|}
    #|
    #|function patchMoonPkg() {
    #|  const moonPkg = path.join(stagingDir, "moon.pkg");
    #|  if (!fs.existsSync(moonPkg)) return;
    #|  const content = fs.readFileSync(moonPkg, "utf8");
    #|  if (content.includes('"moonbitlang/async/fs"')) return;
    #|  const patched = content.replace(
    #|    '"moonbitlang/async",',
    #|    '"moonbitlang/async",\n  "moonbitlang/async/fs",',
    #|  );
    #|  fs.writeFileSync(moonPkg, patched);
    #|}
    #|
    #|function walkDist(dir) {
    #|  for (const name of fs.readdirSync(dir)) {
    #|    const absolutePath = path.join(dir, name);
    #|    const stat = fs.statSync(absolutePath);
    #|    if (stat.isDirectory()) {
    #|      walkDist(absolutePath);
    #|      continue;
    #|    }
    #|    const relativePath = path.relative(distBaseDir, absolutePath).split(path.sep).join("/");
    #|    entries.push([relativePath, fs.readFileSync(absolutePath)]);
    #|  }
    #|}
    #|
    #|function toMoonBytes(buffer) {
    #|  if (buffer.length === 0) return "Bytes::from_array([])";
    #|  return `Bytes::from_array([${Array.from(buffer, byte => byte.toString()).join(", ")}])`;
    #|}
    #|
    #|if (!fs.existsSync(distDir)) {
    #|  console.error(`Missing dist directory: ${distDir}`);
    #|  process.exit(1);
    #|}
    #|
    #|fs.rmSync(stagingDir, { recursive: true, force: true });
    #|copyProject(projectRoot, stagingDir);
    #|linkMooncakes();
    #|patchMoonPkg();
    #|walkDist(distDir);
    #|entries.sort((a, b) => a[0].localeCompare(b[0]));
    #|
    #|const lines = [
    #|  "///|",
    #|  "pub let embedded_dist_files : Array[(String, Bytes)] = [",
    #|  ...entries.map(([filePath, content]) => `  (${JSON.stringify(filePath)}, ${toMoonBytes(content)}),`),
    #|  "]",
    #|  "",
    #|  "///|",
    #|  "pub async fn frontend_url() -> String {",
    #|  '  if @env.get_env_var("LEPUS_DEV_URL") is Some(url) {',
    #|  "    url",
    #|  "  } else {",
    #|  '  let temp_dir = @fs.tmpdir(prefix="lepus-dist")',
    #|  "  for entry in embedded_dist_files {",
    #|  "    let relative_path = entry.0",
    #|  "    let content = entry.1",
    #|  "    let output_path = join_path(temp_dir, relative_path)",
    #|  "    ensure_parent_dir(output_path)",
    #|  '    @fs.write_file(output_path, content, create=0o644)',
    #|  "  }",
    #|  '    file_url(join_path(temp_dir, "dist/index.html"))',
    #|  "  }",
    #|  "}",
    #|  "",
    #|  "///|",
    #|  "async fn ensure_parent_dir(path : String) -> Unit {",
    #|  '  if path.rev_find("/") is Some(index) {',
    #|  '    let parent = path[:index]',
    #|  '    if !@fs.exists(parent) {',
    #|  '      @fs.mkdir(parent, permission=0o755, recursive=true)',
    #|  "    }",
    #|  "  }",
    #|  "}",
    #|  "",
    #|  "///|",
    #|  "fn file_url(path : String) -> String {",
    #|  '  let normalized = path.replace_all(old="\\\\", new="/").replace_all(old=" ", new="%20")',
    #|  '  if normalized.has_prefix("/") {',
    #|  '    "file://" + normalized',
    #|  "  } else {",
    #|  '    "file:///" + normalized',
    #|  "  }",
    #|  "}",
    #|  "",
    #|  "///|",
    #|  "fn join_path(base : String, leaf : String) -> String {",
    #|  '  if base.has_suffix("/") || base.has_suffix("\\\\") {',
    #|  "    base + leaf",
    #|  "  } else {",
    #|  '    base + "/" + leaf',
    #|  "  }",
    #|  "}",
    #|  "",
    #|];
    #|
    #|fs.writeFileSync(outputFile, lines.join("\n"));
  )
}
