///|
fn main {
  @lepus.App::new(
    title="Lepus Upload Plugin",
    html=@lepus_plugin_support.example_html("upload", "Upload Plugin Example"),
    plugins=[@lepus_plugin_upload.plugin()],
  ).run()
}
