///|
fn main {
  @lepus.Window::new(
    title="Lepus Log Plugin",
    source=@lepus_plugin_support.example_html("log", "Log Plugin Example"),
    plugins=[@lepus_plugin_log.plugin()],
  ).run()
}
