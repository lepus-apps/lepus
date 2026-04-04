///|
fn main {
  @lepus.App::new(
    title="Lepus Fs Plugin",
    html=@lepus_plugin_support.example_html("fs", "Fs Plugin Example"),
    plugins=[@lepus_plugin_fs.plugin()],
  ).run()
}
