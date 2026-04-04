///|
fn main {
  @lepus.App::new(
    title="Lepus Os Plugin",
    html=@lepus_plugin_support.example_html("os", "Os Plugin Example"),
    plugins=[@lepus_plugin_os.plugin()],
  ).run()
}
