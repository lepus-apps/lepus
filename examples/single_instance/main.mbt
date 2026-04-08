///|
fn main {
  @lepus.App::new(
    title="Lepus Single Instance Plugin",
    html=@lepus_plugin_support.example_html(
      "single_instance", "Single Instance Plugin Example",
    ),
    plugins=[@lepus_plugin_single_instance.plugin()],
  ).run()
}
