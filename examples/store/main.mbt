///|
fn main {
  @lepus.Window::new(
    title="Lepus Store Plugin",
    html=@lepus_plugin_support.example_html("store", "Store Plugin Example"),
    plugins=[@lepus_plugin_store.plugin()],
  ).run()
}
