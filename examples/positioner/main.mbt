///|
fn main {
  @lepus.App::new(
    title="Lepus Positioner Plugin",
    html=@lepus_plugin_support.example_html(
      "positioner", "Positioner Plugin Example",
    ),
    plugins=[@lepus_plugin_positioner.plugin()],
  ).run()
}
