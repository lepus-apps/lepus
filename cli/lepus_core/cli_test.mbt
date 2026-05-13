///|
test "root command help mentions doctor" {
  let help = root_command().render_help()
  assert_true(help.contains("doctor"))
  assert_true(help.contains("--config"))
}

///|
test "global verbose and config propagate into doctor config" {
  let matches = root_command().parse(
    argv=["-vv", "--config", "lepus.conf.json", "doctor"],
    env={},
  ) catch {
    _ => panic()
  }
  match matches.subcommand {
    Some(("doctor", sub)) => {
      let config = parse_doctor_config(matches, sub)
      assert_eq(config.verbose, 2)
      assert_eq(config.config_path, Some("lepus.conf.json"))
    }
    _ => panic()
  }
}

///|
test "init config accepts vite frontend" {
  let matches = root_command().parse(
    argv=["init", "demo", "--frontend", "vite"],
    env={},
  ) catch {
    _ => panic()
  }
  match matches.subcommand {
    Some(("init", sub)) => {
      let config = parse_init_config(matches, sub)
      assert_eq(config.frontend, "vite")
    }
    _ => panic()
  }
}

///|
test "build config accepts mobile target aliases" {
  let matches = root_command().parse(
    argv=["build", "--target", "android", "--frontend-dir", "dist", "--out-dir", "out"],
    env={},
  ) catch {
    _ => panic()
  }
  match matches.subcommand {
    Some(("build", sub)) => {
      let config = parse_build_config(matches, sub)
      assert_eq(config.target, "android")
      assert_eq(config.dist_dir, Some("dist"))
      assert_eq(config.output_dir, Some("out"))
    }
    _ => panic()
  }
}
