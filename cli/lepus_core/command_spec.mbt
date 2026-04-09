///|
pub fn root_command() -> @argparse.Command {
  let dev = @argparse.Command(
    "dev",
    about="Run the Lepus development workflow.",
    options=[
      @argparse.OptionArg("port", long="port"),
      @argparse.OptionArg("host", long="host"),
      @argparse.OptionArg("frontend-dir", long="frontend-dir"),
    ],
  )
  let build = @argparse.Command(
    "build",
    about="Build the Lepus application.",
    flags=[@argparse.FlagArg("embed-assets", long="embed-assets")],
    options=[
      @argparse.OptionArg("frontend-dir", long="frontend-dir"),
      @argparse.OptionArg("out-dir", long="out-dir"),
    ],
  )
  let doctor = @argparse.Command(
    "doctor",
    about="Inspect the local Lepus toolchain environment.",
    flags=[@argparse.FlagArg("json", long="json")],
  )
  @argparse.Command(
    "lepus",
    about="Lepus desktop application toolkit.",
    version="0.1.0",
    subcommands=[dev, build, doctor],
    flags=[
      @argparse.FlagArg(
        "verbose",
        short='v',
        long="verbose",
        action=@argparse.Count,
        global=true,
      ),
    ],
    options=[
      @argparse.OptionArg("config", long="config", global=true),
      @argparse.OptionArg("cwd", long="cwd", global=true),
    ],
    subcommand_required=true,
  )
}
