///|
async fn main {
  @lepus.Window::new(
    title="Lepus Single Instance Plugin",
    source=@lepus_plugin_support.example_html(
      "single_instance", "Single Instance Plugin Example",
    ),
    plugins=[@lepus_plugin_single_instance.plugin()],
  ).run()
}
