///|
fn main {
  @lepus.App::new(
    title="Lepus Dialog Plugin",
    html=@lepus_plugin_support.example_html("dialog", "Dialog Plugin Example"),
    plugins=[@lepus_plugin_dialog.plugin()],
  ).run()
}
