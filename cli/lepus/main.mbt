///|
async fn main {
  let exit_code = @core.run_cli()
  if exit_code != 0 {
    @sys.exit(exit_code)
  }
}
