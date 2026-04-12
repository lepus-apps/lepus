///|
async fn main {
  @lepus.Window::new(
    title="Lepus Geolocation Plugin",
    source=@lepus_plugin_support.example_html(
      "geolocation", "Geolocation Plugin Example",
    ),
    plugins=[@lepus_plugin_geolocation.plugin()],
  ).run()
}
