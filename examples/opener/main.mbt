///|
fn main {
  @lepus.Window::new(
    title="Lepus Opener Plugin",
    source=@lepus_plugin_support.example_html("opener", "Opener Plugin Example"),
    plugins=[@lepus_plugin_opener.plugin()],
  ).run()
}
