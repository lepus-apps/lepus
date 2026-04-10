///|
fn main {
  @lepus.Window::new(
    title="Lepus Persisted Scope Plugin",
    source=@lepus_plugin_support.example_html(
      "persisted_scope", "Persisted Scope Plugin Example",
    ),
    plugins=[@lepus_plugin_persisted_scope.plugin()],
  ).run()
}
