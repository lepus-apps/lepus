///|
fn main {
  @lepus.App::new(
    title="Lepus Biometric Plugin",
    html=@lepus_plugin_support.example_html(
      "biometric", "Biometric Plugin Example",
    ),
    plugins=[@lepus_plugin_biometric.plugin()],
  ).run()
}
