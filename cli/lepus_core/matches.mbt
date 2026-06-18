///|
pub struct InitConfig {
  project_name : String?
  template : String
  frontend : String
  force : Bool
  cwd : String
  verbose : Int
}

///|
pub struct DevConfig {
  cwd : String
  config_path : String?
  frontend_dir : String?
  port : Int?
  host : String?
  skip_setup : Bool
  verbose : Int
}

///|
pub struct BuildConfig {
  cwd : String
  frontend_dir : String?
  dist_dir : String?
  output_dir : String?
  release : Bool
  skip_frontend : Bool
  skip_moon : Bool
  skip_setup : Bool
  typecheck : Bool
  verbose : Int
}

///|
pub struct SetupConfig {
  cwd : String
  force : Bool
  verbose : Int
}

///|
pub struct DoctorConfig {
  cwd : String
  config_path : String?
  json : Bool
  verbose : Int
}

///|
pub fn parse_init_config(
  root : @argparse.Matches,
  sub : @argparse.Matches,
) -> InitConfig {
  {
    project_name: first_value(sub, "name"),
    template: first_value(sub, "template").unwrap_or("basic"),
    frontend: first_value(sub, "frontend").unwrap_or("vanilla"),
    force: sub.flags.get_or_default("force", false),
    cwd: root_cwd(root),
    verbose: verbosity(root),
  }
}

///|
pub fn parse_dev_config(
  root : @argparse.Matches,
  sub : @argparse.Matches,
) -> DevConfig {
  {
    cwd: root_cwd(root),
    config_path: first_value(root, "config"),
    frontend_dir: first_value(sub, "frontend-dir"),
    port: parse_int_option(first_value(sub, "port")),
    host: first_value(sub, "host"),
    skip_setup: sub.flags.get_or_default("skip-setup", false),
    verbose: verbosity(root),
  }
}

///|
pub fn parse_build_config(
  root : @argparse.Matches,
  sub : @argparse.Matches,
) -> BuildConfig {
  let debug = sub.flags.get_or_default("debug", false)
  {
    cwd: root_cwd(root),
    frontend_dir: first_value(sub, "frontend-dir"),
    dist_dir: first_value(sub, "dist-dir"),
    output_dir: first_value(sub, "out-dir"),
    release: !debug,
    skip_frontend: sub.flags.get_or_default("skip-frontend", false),
    skip_moon: sub.flags.get_or_default("skip-moon", false),
    skip_setup: sub.flags.get_or_default("skip-setup", false),
    typecheck: !sub.flags.get_or_default("no-typecheck", false),
    verbose: verbosity(root),
  }
}

///|
pub fn parse_setup_config(
  root : @argparse.Matches,
  sub : @argparse.Matches,
) -> SetupConfig {
  {
    cwd: root_cwd(root),
    force: sub.flags.get_or_default("force", false),
    verbose: verbosity(root),
  }
}

///|
pub fn parse_doctor_config(
  root : @argparse.Matches,
  sub : @argparse.Matches,
) -> DoctorConfig {
  {
    cwd: root_cwd(root),
    config_path: first_value(root, "config"),
    json: sub.flags.get_or_default("json", false),
    verbose: verbosity(root),
  }
}

///|
fn verbosity(matches : @argparse.Matches) -> Int {
  matches.flag_counts.get_or_default("verbose", 0)
}

///|
fn root_cwd(matches : @argparse.Matches) -> String {
  first_value(matches, "cwd").unwrap_or(get_cwd())
}

///|
fn first_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) => if values.length() == 0 { None } else { Some(values[0]) }
    None => None
  }
}

///|
fn parse_int_option(value : String?) -> Int? {
  match value {
    Some(value) =>
      try @string.parse_int(value) catch {
        _ => None
      } noraise {
        value => Some(value)
      }
    None => None
  }
}
