///|
async fn main {
  @lepus.Window::new(
    title="Lepus Haptics Plugin",
    source=@lepus_plugin_support.example_html(
      "haptics", "Haptics Plugin Example",
    ),
    plugins=[@lepus_plugin_haptics.plugin()],
  ).run()
}
