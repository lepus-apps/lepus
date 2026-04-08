///|
fn main {
  @lepus.Window::new(
    title="Lepus Process Plugin",
    html=@lepus_plugin_support.example_html("process", "Process Plugin Example"),
    plugins=[@lepus_plugin_process.plugin()],
  ).run()
}
