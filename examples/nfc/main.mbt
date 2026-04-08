///|
fn main {
  @lepus.Window::new(
    title="Lepus Nfc Plugin",
    html=@lepus_plugin_support.example_html("nfc", "Nfc Plugin Example"),
    plugins=[@lepus_plugin_nfc.plugin()],
  ).run()
}
