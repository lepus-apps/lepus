///|
fn main {
  @lepus.Window::new(
    title="Lepus Notification Plugin",
    source=@lepus_plugin_support.example_html(
      "notification", "Notification Plugin Example",
    ),
    plugins=[@lepus_plugin_notification.plugin()],
  ).run()
}
