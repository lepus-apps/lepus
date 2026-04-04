///|
fn main {
  @lepus.App::new(
    title="Lepus Websocket Plugin",
    html=@lepus_plugin_support.example_html(
      "websocket", "Websocket Plugin Example",
    ),
    plugins=[@lepus_plugin_websocket.plugin()],
  ).run()
}
