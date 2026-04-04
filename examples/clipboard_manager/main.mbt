///|
fn main {
  @lepus.App::new(
    title="Lepus Clipboard Manager Plugin",
    html=@lepus_plugin_support.example_html(
      "clipboard-manager", "Clipboard Manager Plugin Example",
    ),
    plugins=[@lepus_plugin_clipboard_manager.plugin()],
  ).run()
}
