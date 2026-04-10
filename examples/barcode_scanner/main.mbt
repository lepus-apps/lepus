///|
fn main {
  @lepus.Window::new(
    title="Lepus Barcode Scanner Plugin",
    source=@lepus_plugin_support.example_html(
      "barcode_scanner", "Barcode Scanner Plugin Example",
    ),
    plugins=[@lepus_plugin_barcode_scanner.plugin()],
  ).run()
}
