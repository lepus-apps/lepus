///|
fn main {
  let root = root_command()
  let matches = root.parse() catch {
    err => {
      println(err.to_string())
      exit_process(2)
      abort("unreachable")
    }
  }
  let exit_code = match matches.subcommand {
    Some(("doctor", sub)) => run_doctor(parse_doctor_config(matches, sub))
    Some(("init", sub)) => run_init(parse_init_config(matches, sub))
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
  if exit_code != 0 {
    exit_process(exit_code)
  }
}
