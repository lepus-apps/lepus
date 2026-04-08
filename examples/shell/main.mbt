///|
fn main {
  @lepus.Window::new(
    title="Lepus Shell Plugin",
    html=@lepus_plugin_support.example_html("shell", "Shell Plugin Example"),
    plugins=[@lepus_plugin_shell.plugin()],
  ).run()
}
