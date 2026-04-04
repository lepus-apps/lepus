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
test "init config defaults and cwd are inferred" {
  let matches = root_command().parse(argv=["init", "demo"], env={}) catch {
    _ => panic()
  }
  match matches.subcommand {
    Some(("init", sub)) => {
      let config = parse_init_config(matches, sub)
      assert_eq(config.project_name, Some("demo"))
      assert_eq(config.template, "basic")
      assert_eq(config.frontend, "vanilla")
      assert_eq(config.force, false)
    }
    _ => panic()
  }
}
