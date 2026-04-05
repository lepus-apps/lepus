///|
priv struct GeneratedFile {
  path : String
  content : String
}

///|
pub fn run_init(config : InitConfig) -> Int {
  guard config.template == "basic" else {
    println("Unsupported template: " + config.template)
    return 1
  }
  guard config.frontend == "vanilla" || config.frontend == "vite" else {
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

  let files = scaffold_files(package_name, target_dir, config.frontend)

  for file in files {
    guard write_text_file(file.path, file.content) else {
      println("Failed to write file: " + file.path)
      return 1
    }
  }

  println("Initialized Lepus app at " + target_dir)
  println("Next steps:")
  println("  cd " + target_dir)
  match config.frontend {
    "vite" => {
      println("  npm install")
      println(
        "  moon run --target native .mooncakes/lepus-apps/lepus/cli/lepus/main.mbt -- dev",
      )
    }
    _ => println("  moon run --target native main.mbt")
  }
  0
}

///|
fn scaffold_files(
  package_name : String,
  target_dir : String,
  frontend : String,
) -> Array[GeneratedFile] {
  let common : Array[GeneratedFile] = [
    {
      path: join_path(target_dir, "moon.mod.json"),
      content: moon_mod_json(package_name, frontend),
    },
    { path: join_path(target_dir, "moon.pkg"), content: moon_pkg(frontend) },
    {
      path: join_path(target_dir, "main.mbt"),
      content: main_mbt(package_name, frontend),
    },
    {
      path: join_path(target_dir, "index.mbt"),
      content: embed_module_source(index_html(package_name)),
    },
    {
      path: join_path(target_dir, ".gitignore"),
      content: gitignore_text(frontend),
    },
    {
      path: join_path(target_dir, "README.md"),
      content: readme_text(package_name, frontend),
    },
  ]
  match frontend {
    "vite" =>
      [
        ..common,
        {
          path: join_path(target_dir, "package.json"),
          content: package_json(package_name),
        },
        {
          path: join_path(target_dir, "vite.config.js"),
          content: vite_config_js(),
        },
        {
          path: join_path(target_dir, "index.html"),
          content: vite_index_html(package_name),
        },
        {
          path: join_path(join_path(target_dir, "src"), "main.js"),
          content: vite_main_js(package_name),
        },
        {
          path: join_path(join_path(target_dir, "src"), "style.css"),
          content: vite_style_css(),
        },
      ]
    _ =>
      [
        ..common,
        {
          path: join_path(target_dir, "index.html"),
          content: index_html(package_name),
        },
      ]
  }
}

///|
fn moon_mod_json(package_name : String, frontend : String) -> String {
  let deps = match frontend {
    "vite" => { "lepus-apps/lepus": "0.1.0", "moonbitlang/x": "0.4.41" }
    _ => { "lepus-apps/lepus": "0.1.0" }
  }
  (
    {
      "name": "username/\{package_name}",
      "version": "0.1.0",
      "deps": deps,
      "source": "",
      "preferred-target": "native",
    } : Json).stringify()
}

///|
fn moon_pkg(frontend : String) -> String {
  let pre_build = match frontend {
    "vanilla" =>
      (
        #|  "pre-build": [
        #|    {
        #|      "command": ":embed -i $input -o $output",
        #|      "input": "index.html",
        #|      "output": "index.mbt"
        #|    }
        #|  ],
      )
    _ => ""
  }
  "import {\n" +
  "  \"lepus-apps/lepus\",\n" +
  (if frontend == "vite" { "  \"moonbitlang/x/sys\",\n" } else { "" }) +
  "}\n\n" +
  "supported_targets = \"+native\"\n\n" +
  "options(\n" +
  "  \"is-main\": true,\n" +
  "  link: { \"native\": { \"cc\": \".mooncakes/lepus/cc\" } },\n" +
  pre_build +
  "  targets: { \"main.mbt\": [ \"native\" ] },\n" +
  ")\n"
}

///|
fn main_mbt(package_name : String, frontend : String) -> String {
  match frontend {
    "vite" =>
      (
        #|///|
        #|fn main {
        #|  match @sys.get_env_var("LEPUS_DEV_URL") {
        #|    Some(url) =>
        $|      @lepus.App::new(title="\{package_name}", url=url).run()
        #|    None =>
        $|      @lepus.App::new(title="\{package_name}", html=resource).run()
        #|  }
        #|}
      )
    _ =>
      (
        #|///|
        #|fn main {
        $|  @lepus.App::new(title="\{package_name}", html=resource).run()
        #|}
      )
  }
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
fn vite_index_html(package_name : String) -> String {
  (
    #|<!doctype html>
    #|<html lang="en">
    #|  <head>
    #|    <meta charset="UTF-8" />
    #|    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    $|    <title>\{package_name}</title>
    #|    <script type="module" src="/src/main.js"></script>
    #|  </head>
    #|  <body>
    #|    <div id="app"></div>
    #|  </body>
    #|</html>
  )
}

///|
fn package_json(package_name : String) -> String {
  (
    {
      "name": package_name,
      "private": true,
      "version": "0.1.0",
      "type": "module",
      "scripts": {
        "dev": "vite",
        "build": "vite build",
        "preview": "vite preview",
      },
      "devDependencies": {
        "vite": "latest",
        "vite-plugin-singlefile": "latest",
      },
    } : Json).stringify()
}

///|
fn vite_config_js() -> String {
  (
    #|import { defineConfig } from "vite";
    #|import { viteSingleFile } from "vite-plugin-singlefile";
    #|
    #|export default defineConfig({
    #|  plugins: [viteSingleFile()],
    #|  build: {
    #|    outDir: "dist",
    #|    emptyOutDir: true,
    #|    cssCodeSplit: false,
    #|    assetsInlineLimit: 100000000,
    #|  },
    #|});
  )
}

///|
fn vite_main_js(package_name : String) -> String {
  (
    #|import "./style.css";
    #|
    #|const app = document.querySelector("#app");
    #|
    #|if (app) {
    $|  app.innerHTML = `<main class="shell"><span class="eyebrow">Lepus + Vite</span><h1>\{package_name}</h1><p>The frontend is being served by Vite in development and embedded into the native host for production builds.</p></main>`;
    #|}
  )
}

///|
fn vite_style_css() -> String {
  (
    #|:root {
    #|  color-scheme: light;
    #|  font-family: "Avenir Next", "Segoe UI", sans-serif;
    #|  background: linear-gradient(135deg, #f7f1df 0%, #dfeaf6 100%);
    #|  color: #1f2937;
    #|}
    #|
    #|* {
    #|  box-sizing: border-box;
    #|}
    #|
    #|body {
    #|  margin: 0;
    #|  min-height: 100vh;
    #|  display: grid;
    #|  place-items: center;
    #|}
    #|
    #|.shell {
    #|  width: min(560px, calc(100vw - 48px));
    #|  padding: 32px;
    #|  border-radius: 24px;
    #|  background: rgba(255, 255, 255, 0.84);
    #|  box-shadow: 0 20px 60px rgba(15, 23, 42, 0.14);
    #|}
    #|
    #|.eyebrow {
    #|  display: inline-block;
    #|  margin-bottom: 12px;
    #|  font-size: 12px;
    #|  letter-spacing: 0.16em;
    #|  text-transform: uppercase;
    #|  color: #b45309;
    #|}
    #|
    #|h1 {
    #|  margin: 0 0 12px;
    #|  font-size: clamp(32px, 5vw, 44px);
    #|}
    #|
    #|p {
    #|  margin: 0;
    #|  line-height: 1.6;
    #|}
  )
}

///|
fn gitignore_text(frontend : String) -> String {
  match frontend {
    "vite" => "_build/\n.moon/\n.mooncakes/\nnode_modules/\ndist/\n*.mbti\n"
    _ => "_build/\n.moon/\n.mooncakes/\n*.mbti\n"
  }
}

///|
fn readme_text(package_name : String, frontend : String) -> String {
  match frontend {
    "vite" =>
      (
        #|# 
        $|\{package_name}
        #|
        #|Generated by `lepus init --frontend vite`.
        #|
        #|## Development
        #|
        #|```sh
        #|npm install
        #|moon run --target native .mooncakes/lepus-apps/lepus/cli/lepus/main.mbt -- dev
        #|```
        #|
        #|## Build
        #|
        #|```sh
        #|moon run --target native .mooncakes/lepus-apps/lepus/cli/lepus/main.mbt -- build
        #|```
      )
    _ => "# " + package_name + "\n\nGenerated by `lepus init`.\n"
  }
}
