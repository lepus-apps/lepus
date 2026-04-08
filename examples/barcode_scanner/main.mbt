///|
fn main {
  @lepus.App::new(
    title="Lepus Barcode Scanner Plugin",
    html=@lepus_plugin_support.example_html(
      "barcode_scanner", "Barcode Scanner Plugin Example",
    ),
    plugins=[@lepus_plugin_barcode_scanner.plugin()],
  ).run()
}
