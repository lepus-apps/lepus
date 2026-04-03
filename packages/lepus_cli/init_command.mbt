///|
struct GeneratedFile {
  path : String
  content : String
}

///|
pub fn run_init(config : InitConfig) -> Int {
  guard config.template == "basic" else {
    println("Unsupported template: " + config.template)
    return 1
  }
  guard config.frontend == "vanilla" else {
    println("Unsupported frontend: " + config.frontend)
    return 1
  }

  let project_name = config.project_name.unwrap_or("lepus-app")
  let target_dir = join_path(config.cwd, project_name)
  let package_name = project_basename(project_name)

  if path_exists(target_dir) && !config.force {
    println("Target already exists: " + target_dir)
    println("Re-run with --force to overwrite scaffold files.")
    return 1
  }

  guard mkdir_p(target_dir) else {
    println("Failed to create project directory: " + target_dir)
    return 1
  }

  let resolved_target_dir = canonicalize_path(target_dir)
  let resolved_repo_root = canonicalize_path(get_repo_root())
  let dep_path = relative_path(resolved_target_dir, resolved_repo_root)

  let files : Array[GeneratedFile] = [
    {
      path: join_path(target_dir, "moon.mod.json"),
      content: moon_mod_json(package_name),
    },
    { path: join_path(target_dir, "moon.pkg"), content: moon_pkg(dep_path) },
    { path: join_path(target_dir, "main.mbt"), content: main_mbt(package_name) },
    {
      path: join_path(target_dir, "index.html"),
      content: index_html(package_name),
    },
    { path: join_path(target_dir, ".gitignore"), content: gitignore_text() },
    {
      path: join_path(target_dir, "README.md"),
      content: readme_text(package_name),
    },
  ]

  for file in files {
    guard write_text_file(file.path, file.content) else {
      println("Failed to write file: " + file.path)
      return 1
    }
  }

  println("Initialized Lepus app at " + target_dir)
  println("Next steps:")
  println("  cd " + target_dir)
  println("  moon run --target native main.mbt")
  0
}

///|
fn project_basename(project_name : String) -> String {
  let parts = project_name.split("/").map(part => part.to_string()).to_array()
  parts.last().unwrap_or(project_name)
}

///|
fn join_path(base : String, leaf : String) -> String {
  if base.has_suffix("/") {
    base + leaf
  } else {
    base + "/" + leaf
  }
}

///|
fn relative_path(from_dir : String, to_dir : String) -> String {
  let from_parts = path_parts(from_dir)
  let to_parts = path_parts(to_dir)
  let mut common = 0
  let limit = if from_parts.length() < to_parts.length() {
    from_parts.length()
  } else {
    to_parts.length()
  }
  while common < limit && from_parts[common] == to_parts[common] {
    common = common + 1
  }

  let parts : Array[String] = []
  for _ in common..<from_parts.length() {
    parts.push("..")
  }
  for index in common..<to_parts.length() {
    parts.push(to_parts[index])
  }

  if parts.length() == 0 {
    "."
  } else {
    parts.join("/")
  }
}

///|
fn path_parts(path : String) -> Array[String] {
  let parts : Array[String] = []
  for part in path.split("/").map(part => part.to_string()) {
    if part != "" && part != "." {
      parts.push(part)
    }
  }
  parts
}

///|
fn moon_mod_json(package_name : String) -> String {
  (
    {
      "name": "username/\{package_name}",
      "version": "0.1.0",
      "deps": { "lepus-apps/lepus": "0.1.0" },
      "source": "",
      "preferred-target": "native",
    } : Json).stringify()
}

///|
fn moon_pkg(dep_path : String) -> String {
  "import {\n" +
  "  \"lepus-apps/lepus/packages/lepus\",\n" +
  "}\n\n" +
  "supported_targets = \"+native\"\n\n" +
  "options(\n" +
  "  \"is-main\": true,\n" +
  "  link: {\n" +
  "    \"native\": {\n" +
  "      \"cc-link-flags\": \"-L" +
  dep_path +
  "/packages/lepus_runtime_webview/lib -lwebview -Wl,-rpath,@loader_path/../../../../" +
  dep_path +
  "/packages/lepus_runtime_webview/lib\"\n" +
  "    }\n" +
  "  },\n" +
  "  \"pre-build\": [\n" +
  "    {\n" +
  "      \"command\": \":embed -i $input -o $output\",\n" +
  "      \"input\": \"index.html\",\n" +
  "      \"output\": \"index.mbt\"\n" +
  "    }\n" +
  "  ],\n" +
  "  targets: { \"main.mbt\": [ \"native\" ] },\n" +
  ")\n"
}

///|
fn main_mbt(package_name : String) -> String {
  "///|\n" +
  "fn main {\n" +
  "  @lepus.default_app()\n" +
  "  .title(\"" +
  package_name +
  "\")\n" +
  "  .html(resource)\n" +
  "  .build()\n" +
  "  .run()\n" +
  "}\n"
}

///|
fn index_html(package_name : String) -> String {
  "<!doctype html>\n" +
  "<html lang=\"en\">\n" +
  "  <head>\n" +
  "    <meta charset=\"UTF-8\" />\n" +
  "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n" +
  "    <title>" +
  package_name +
  "</title>\n" +
  "    <style>\n" +
  "      body {\n" +
  "        font-family: system-ui, sans-serif;\n" +
  "        margin: 0;\n" +
  "        min-height: 100vh;\n" +
  "        display: grid;\n" +
  "        place-items: center;\n" +
  "        background: linear-gradient(135deg, #f5f1e8, #dce8f5);\n" +
  "        color: #1f2937;\n" +
  "      }\n" +
  "      main {\n" +
  "        text-align: center;\n" +
  "        padding: 32px;\n" +
  "        border-radius: 20px;\n" +
  "        background: rgba(255, 255, 255, 0.82);\n" +
  "        box-shadow: 0 20px 60px rgba(31, 41, 55, 0.12);\n" +
  "      }\n" +
  "    </style>\n" +
  "  </head>\n" +
  "  <body>\n" +
  "    <main>\n" +
  "      <h1>Hello from Lepus</h1>\n" +
  "      <p>Your desktop app scaffold is ready.</p>\n" +
  "      <p><strong>" +
  package_name +
  "</strong></p>\n" +
  "    </main>\n" +
  "  </body>\n" +
  "</html>\n"
}

///|
fn gitignore_text() -> String {
  "_build/\n.moon/\n.mooncakes/\n*.mbti\n"
}

///|
fn readme_text(package_name : String) -> String {
  "# " + package_name + "\n\nGenerated by `lepus init`.\n"
}
