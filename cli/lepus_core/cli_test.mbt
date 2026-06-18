///|
test "root command help mentions setup and doctor" {
  let help = root_command().render_help()
  assert_true(help.contains("setup"))
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
      @debug.assert_eq(config.verbose, 2)
      @debug.assert_eq(config.config_path, Some("lepus.conf.json"))
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
      @debug.assert_eq(config.frontend, "vite")
    }
    _ => panic()
  }
}

///|
test "dev config parses skip setup" {
  let matches = root_command().parse(
    argv=["--cwd", "/tmp/app", "dev", "--port", "2333", "--skip-setup"],
    env={},
  ) catch {
    _ => panic()
  }
  match matches.subcommand {
    Some(("dev", sub)) => {
      let config = parse_dev_config(matches, sub)
      @debug.assert_eq(config.cwd, "/tmp/app")
      @debug.assert_eq(config.port, Some(2333))
      @debug.assert_eq(config.skip_setup, true)
    }
    _ => panic()
  }
}

///|
test "build config owns frontend and moon build flags" {
  let matches = root_command().parse(
    argv=[
      "--cwd", "/tmp/app", "build", "--debug", "--frontend-dir", "ui", "--dist-dir",
      "build", "--out-dir", ".lepus", "--skip-frontend", "--skip-moon", "--skip-setup",
      "--no-typecheck",
    ],
    env={},
  ) catch {
    _ => panic()
  }
  match matches.subcommand {
    Some(("build", sub)) => {
      let config = parse_build_config(matches, sub)
      @debug.assert_eq(config.cwd, "/tmp/app")
      @debug.assert_eq(config.frontend_dir, Some("ui"))
      @debug.assert_eq(config.dist_dir, Some("build"))
      @debug.assert_eq(config.output_dir, Some(".lepus"))
      @debug.assert_eq(config.release, false)
      @debug.assert_eq(config.skip_frontend, true)
      @debug.assert_eq(config.skip_moon, true)
      @debug.assert_eq(config.skip_setup, true)
      @debug.assert_eq(config.typecheck, false)
    }
    _ => panic()
  }
}

///|
test "setup config parses force" {
  let matches = root_command().parse(argv=["setup", "--force"], env={}) catch {
    _ => panic()
  }
  match matches.subcommand {
    Some(("setup", sub)) => {
      let config = parse_setup_config(matches, sub)
      @debug.assert_eq(config.force, true)
    }
    _ => panic()
  }
}
