///|
pub async fn run_init(config : InitConfig) -> Int {
  let name = config.project_name.unwrap_or(".")
  let project_dir = resolve_path(config.cwd, Some(name))
  if @fs.exists(project_dir) && !config.force {
    println("Project directory already exists: " + project_dir)
    println("Use --force to scaffold into an existing directory.")
    return 1
  }
  if !@fs.exists(project_dir) {
    @fs.mkdir(project_dir, permission=0o755, recursive=true)
  }
  write_init_file(project_dir, "moon.mod.json", init_moon_mod(name))
  write_init_file(project_dir, "moon.pkg", init_moon_pkg())
  write_init_file(project_dir, "main.mbt", init_main_source(name))
  write_init_file(project_dir, "README.md", init_readme(name, config))
  println("Created Lepus app at " + project_dir)
  println("Next: cd " + name + " && moon run --target native main.mbt")
  0
}

///|
async fn write_init_file(dir : String, name : String, content : String) -> Unit {
  @fs.write_file(join_path(dir, name), content, create=0o644, truncate=true)
}

///|
fn init_moon_mod(name : String) -> String {
  (
    #|{
    #|  "name": "
  ) + project_basename(name) + (
    #|",
    #|  "version": "0.1.0",
    #|  "deps": {
    #|    "lepus-apps/lepus": "0.1.7",
    #|    "moonbitlang/async": "0.17.1"
    #|  },
    #|  "preferred-target": "native"
    #|}
  )
}

///|
fn init_moon_pkg() -> String {
  (
    #|import {
    #|  "lepus-apps/lepus",
    #|  "moonbitlang/async",
    #|}
    #|
    #|supported_targets = "+native"
    #|
    #|options(
    #|  "is-main": true,
    #|  targets: { "main.mbt": [ "native" ] },
    #|)
  )
}

///|
fn init_main_source(name : String) -> String {
  (
    #|///|
    #|async fn main {
    #|  @lepus.Window::new(
    #|    title="
  ) + project_basename(name) + (
    #|",
    #|    source=@lepus.Source::html("<h1>Hello Lepus</h1>"),
    #|  ).run()
    #|}
  )
}

///|
fn init_readme(name : String, config : InitConfig) -> String {
  "# " + project_basename(name) + "\n\n" +
  "Template: " + config.template + "\n\n" +
  "Frontend: " + config.frontend + "\n\n" +
  "Run with `moon run --target native main.mbt`.\n"
}
