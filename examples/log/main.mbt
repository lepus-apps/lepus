///|
fn main {
  @lepus.App::new(
    title="Lepus Log Plugin",
    html=@lepus_plugin_support.example_html("log", "Log Plugin Example"),
    plugins=[@lepus_plugin_log.plugin()],
  ).run()
}
