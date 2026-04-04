///|
fn main {
  @lepus.App::new(
    title="Lepus Http Plugin",
    html=@lepus_plugin_support.example_html("http", "Http Plugin Example"),
    plugins=[@lepus_plugin_http.plugin()],
  ).run()
}
