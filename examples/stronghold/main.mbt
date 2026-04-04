///|
fn main {
  @lepus.App::new(
    title="Lepus Stronghold Plugin",
    html=@lepus_plugin_support.example_html(
      "stronghold", "Stronghold Plugin Example",
    ),
    plugins=[@lepus_plugin_stronghold.plugin()],
  ).run()
}
