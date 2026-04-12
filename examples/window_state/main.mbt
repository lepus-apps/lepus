///|
async fn main {
  @lepus.Window::new(
    title="Lepus Window State Plugin",
    source=@lepus_plugin_support.example_html(
      "window_state", "Window State Plugin Example",
    ),
    plugins=[@lepus_plugin_window_state.plugin()],
  ).run()
}
