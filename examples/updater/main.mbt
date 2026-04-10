///|
fn main {
  @lepus.Window::new(
    title="Lepus Updater Plugin",
    source=@lepus_plugin_support.example_html(
      "updater", "Updater Plugin Example",
    ),
    plugins=[@lepus_plugin_updater.plugin()],
  ).run()
}
