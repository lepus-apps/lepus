///|
async fn main {
  @lepus.Window::new(
    title="Lepus Websocket Plugin",
    source=@lepus_plugin_support.example_html(
      "websocket", "Websocket Plugin Example",
    ),
    plugins=[@lepus_plugin_websocket.plugin()],
  ).run()
}
