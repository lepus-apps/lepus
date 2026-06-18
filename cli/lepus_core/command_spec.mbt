///|
pub fn root_command() -> @argparse.Command {
  let dev = @argparse.Command(
    "dev",
    about="Run the Lepus development workflow.",
    flags=[FlagArg("skip-setup", long="skip-setup")],
    options=[
      OptionArg("port", long="port"),
      OptionArg("host", long="host"),
      OptionArg("frontend-dir", long="frontend-dir"),
    ],
  )
  let build = @argparse.Command(
    "build",
    about="Build the Lepus application.",
    flags=[
      FlagArg("debug", long="debug"),
      FlagArg("no-typecheck", long="no-typecheck"),
      FlagArg("skip-frontend", long="skip-frontend"),
      FlagArg("skip-moon", long="skip-moon"),
      FlagArg("skip-setup", long="skip-setup"),
    ],
    options=[
      OptionArg("frontend-dir", long="frontend-dir"),
      OptionArg("dist-dir", long="dist-dir"),
      OptionArg("out-dir", long="out-dir"),
    ],
  )
  let setup = @argparse.Command(
    "setup",
    about="Prepare the Lepus MoonBit toolchain helpers.",
    flags=[FlagArg("force", long="force")],
  )
  let init = @argparse.Command(
    "init",
    about="Create a new Lepus project.",
    flags=[FlagArg("force", long="force")],
    options=[
      OptionArg("template", long="template"),
      OptionArg("frontend", long="frontend"),
    ],
    positionals=[PositionArg("name")],
  )
  let doctor = @argparse.Command(
    "doctor",
    about="Inspect the local Lepus toolchain environment.",
    flags=[FlagArg("json", long="json")],
  )
  Command(
    "lepus",
    about="Lepus desktop application toolkit.",
    version="0.1.8",
    subcommands=[init, dev, build, setup, doctor],
    flags=[
      FlagArg("verbose", short='v', long="verbose", action=Count, global=true),
    ],
    options=[
      OptionArg("config", long="config", global=true),
      OptionArg("cwd", long="cwd", global=true),
    ],
    subcommand_required=true,
  )
}
