///|
fn main {
  @lepus.Window::new(
    title="Lepus Dialog Plugin",
    source=@lepus_plugin_support.example_html("dialog", "Dialog Plugin Example"),
    plugins=[@lepus_plugin_dialog.plugin()],
  ).run()
}
