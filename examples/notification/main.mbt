///|
fn main {
  @lepus.App::new(
    title="Lepus Notification Plugin",
    html=@lepus_plugin_support.example_html(
      "notification", "Notification Plugin Example",
    ),
    plugins=[@lepus_plugin_notification.plugin()],
  ).run()
}
