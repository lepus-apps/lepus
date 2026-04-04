///|
fn main {
  @lepus.App::new(
    title="Lepus Persisted Scope Plugin",
    html=@lepus_plugin_support.example_html(
      "persisted-scope", "Persisted Scope Plugin Example",
    ),
    plugins=[@lepus_plugin_persisted_scope.plugin()],
  ).run()
}
