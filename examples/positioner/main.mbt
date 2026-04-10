///|
fn main {
  @lepus.Window::new(
    title="Lepus Positioner Plugin",
    source=@lepus_plugin_support.example_html(
      "positioner", "Positioner Plugin Example",
    ),
    plugins=[@lepus_plugin_positioner.plugin()],
  ).run()
}
