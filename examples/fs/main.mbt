///|
fn main {
  @lepus.Window::new(
    title="Lepus Fs Plugin",
    html=@lepus_plugin_support.example_html("fs", "Fs Plugin Example"),
    plugins=[@lepus_plugin_fs.plugin()],
  ).run()
}
