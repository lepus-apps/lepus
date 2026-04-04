///|
fn main {
  @lepus.App::new(
    title="Lepus Sql Plugin",
    html=@lepus_plugin_support.example_html("sql", "Sql Plugin Example"),
    plugins=[@lepus_plugin_sql.plugin()],
  ).run()
}
