///|
fn main {
  @lepus.App::new(
    title="Lepus Localhost Plugin",
    html=@lepus_plugin_support.example_html(
      "localhost", "Localhost Plugin Example",
    ),
    plugins=[@lepus_plugin_localhost.plugin()],
  ).run()
}
