///|
fn main {
  @lepus.App::new(
    title="Lepus Autostart Plugin",
    html=@lepus_plugin_support.example_html(
      "autostart", "Autostart Plugin Example",
    ),
    plugins=[@lepus_plugin_autostart.plugin()],
  ).run()
}
