///|
fn main {
  @lepus.Window::new(
    title="Lepus Global Shortcut Plugin",
    source=@lepus_plugin_support.example_html(
      "global-shortcut", "Global Shortcut Plugin Example",
    ),
    plugins=[@lepus_plugin_global_shortcut.plugin()],
  ).run()
}
