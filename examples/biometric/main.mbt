///|
fn main {
  @lepus.Window::new(
    title="Lepus Biometric Plugin",
    source=@lepus_plugin_support.example_html(
      "biometric", "Biometric Plugin Example",
    ),
    plugins=[@lepus_plugin_biometric.plugin()],
  ).run()
}
