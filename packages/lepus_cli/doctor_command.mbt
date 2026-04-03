///|
struct DoctorCheck {
  name : String
  ok : Bool
  detail : String
}

///|
pub fn run_doctor(config : DoctorConfig) -> Int {
  let checks = collect_doctor_checks(config)
  if config.json {
    print_doctor_json(checks)
  } else {
    print_doctor_text(config, checks)
  }
  if all_checks_ok(checks) {
    0
  } else {
    1
  }
}

///|
fn collect_doctor_checks(config : DoctorConfig) -> Array[DoctorCheck] {
  let moon_ok = has_command("moon")
  let module_ok = path_exists(config.cwd + "/moon.mod.json")
  let config_ok = has_lepus_config(config)
  let webview_ok = has_webview_runtime()
  let platform = get_platform()
  [
    {
      name: "moon",
      ok: moon_ok,
      detail: if moon_ok {
        "moon is available"
      } else {
        "moon is not in PATH"
      },
    },
    {
      name: "module",
      ok: module_ok,
      detail: if module_ok {
        "moon.mod.json found"
      } else {
        "moon.mod.json not found in cwd"
      },
    },
    {
      name: "config",
      ok: config_ok,
      detail: if config_ok {
        config_path_message(config)
      } else {
        "no Lepus config file found"
      },
    },
    { name: "webview", ok: webview_ok, detail: webview_message() },
    {
      name: "platform",
      ok: platform == "macos" || platform == "linux",
      detail: "platform=" + platform,
    },
  ]
}

///|
fn has_lepus_config(config : DoctorConfig) -> Bool {
  match config.config_path {
    Some(path) => path_exists(path)
    None => {
      for path in default_config_paths(config.cwd) {
        if path_exists(path) {
          return true
        }
      }
      false
    }
  }
}

///|
fn config_path_message(config : DoctorConfig) -> String {
  match config.config_path {
    Some(path) => "config found at " + path
    None => {
      for path in default_config_paths(config.cwd) {
        if path_exists(path) {
          return "config found at " + path
        }
      }
      "config found at lepus.conf.json"
    }
  }
}

///|
fn default_config_paths(cwd : String) -> Array[String] {
  [cwd + "/lepus.conf.json", cwd + "/lepus.json"]
}

///|
fn has_webview_runtime() -> Bool {
  getenv("DYLD_LIBRARY_PATH") is Some(_) ||
  getenv("LD_LIBRARY_PATH") is Some(_) ||
  getenv("PATH") is Some(_)
}

///|
fn webview_message() -> String {
  if getenv("DYLD_LIBRARY_PATH") is Some(_) {
    "DYLD_LIBRARY_PATH is set"
  } else if getenv("LD_LIBRARY_PATH") is Some(_) {
    "LD_LIBRARY_PATH is set"
  } else if getenv("PATH") is Some(_) {
    "PATH is set; relying on system webview library resolution"
  } else {
    "no library search environment detected"
  }
}

///|
fn all_checks_ok(checks : Array[DoctorCheck]) -> Bool {
  for check in checks {
    if !check.ok {
      return false
    }
  }
  true
}

///|
fn print_doctor_text(
  config : DoctorConfig,
  checks : Array[DoctorCheck],
) -> Unit {
  println("Lepus doctor")
  println("cwd: " + config.cwd)
  println("verbose: " + config.verbose.to_string())
  for check in checks {
    let status = if check.ok { "ok" } else { "fail" }
    println("[" + status + "] " + check.name + ": " + check.detail)
  }
}

///|
fn print_doctor_json(checks : Array[DoctorCheck]) -> Unit {
  let items : Array[Json] = []
  for check in checks {
    items.push({ "name": check.name, "ok": check.ok, "detail": check.detail })
  }
  println(items.to_json().stringify())
}
