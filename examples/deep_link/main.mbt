///|
fn main {
  @lepus.Window::new(
    title="Lepus Deep Link Plugin",
    html=@lepus_plugin_support.example_html(
      "deep_link", "Deep Link Plugin Example",
    ),
    plugins=[@lepus_plugin_deep_link.plugin()],
  ).run()
}
