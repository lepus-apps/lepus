///|
fn main {
  @lepus.Window::new(
    title="Lepus Sql Plugin",
    source=@lepus_plugin_support.example_html("sql", "Sql Plugin Example"),
    plugins=[@lepus_plugin_sql.plugin()],
  ).run()
}
