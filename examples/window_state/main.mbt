///|
fn main {
  @lepus.App::new(
    title="Lepus Window State Plugin",
    html=@lepus_plugin_support.example_html(
      "window-state", "Window State Plugin Example",
    ),
    plugins=[@lepus_plugin_window_state.plugin()],
  ).run()
}
