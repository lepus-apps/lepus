///|
pub async fn run_cli() -> Int {
  let root = root_command()
  let matches = root.parse() catch {
    err => {
      println(err.to_string())
      return 2
    }
  }
  match matches.subcommand {
    Some(("doctor", sub)) => run_doctor(parse_doctor_config(matches, sub))
    Some(("dev", sub)) => run_dev(parse_dev_config(matches, sub))
    Some(("build", sub)) => run_build(parse_build_config(matches, sub))
    Some((name, _)) => {
      println("Unknown command: " + name)
      1
    }
    None => {
      println(root.render_help())
      1
    }
  }
}
