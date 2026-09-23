///|
async fn main {
  @lepus.Window(
    title="Lepus Stronghold Plugin",
    source=@lepus_plugin_support.example_html(
      "stronghold", "Stronghold Plugin Example",
    ),
    plugins=[@lepus_plugin_stronghold.plugin()],
  ).run()
}
