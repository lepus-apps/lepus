///|
fn main {
  @lepus.App::new(
    title="Lepus Geolocation Plugin",
    html=@lepus_plugin_support.example_html(
      "geolocation", "Geolocation Plugin Example",
    ),
    plugins=[@lepus_plugin_geolocation.plugin()],
  ).run()
}
