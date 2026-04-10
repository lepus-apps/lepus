///|
fn main {
  @lepus.Window::new(
    title="Lepus Localhost Plugin",
    source=@lepus_plugin_support.example_html(
      "localhost", "Localhost Plugin Example",
    ),
    plugins=[@lepus_plugin_localhost.plugin()],
  ).run()
}
