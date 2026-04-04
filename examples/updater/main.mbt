///|
fn main {
  @lepus.App::new(
    title="Lepus Updater Plugin",
    html=@lepus_plugin_support.example_html("updater", "Updater Plugin Example"),
    plugins=[@lepus_plugin_updater.plugin()],
  ).run()
}
