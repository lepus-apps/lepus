///|
fn main {
  @lepus.Window::new(
    title="Lepus Autostart Plugin",
    source=@lepus_plugin_support.example_html(
      "autostart", "Autostart Plugin Example",
    ),
    plugins=[@lepus_plugin_autostart.plugin()],
  ).run()
}
