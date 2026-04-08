///|
fn main {
  @lepus.Window::new(
    title="Lepus Cli Plugin",
    html=@lepus_plugin_support.example_html("cli", "Cli Plugin Example"),
    plugins=[@lepus_plugin_cli.plugin()],
  ).run()
}
