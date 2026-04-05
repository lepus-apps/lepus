///|
pub struct WindowConfig {
  title : String
  width : Int
  height : Int
  debug : Int
  html : String?
  url : String?
} derive(Show, Eq, ToJson, FromJson, Hash)

///|
pub struct App {
  config : WindowConfig
  plugins : Array[@webview.Plugin]
} derive(Show, Eq, ToJson, FromJson, Hash)

///|
pub fn App::new(
  title? : String = "Lepus App",
  width? : Int = 800,
  height? : Int = 600,
  debug? : Int = 0,
  html? : String,
  url? : String,
  plugins? : Array[@webview.Plugin] = [],
) -> App {
  { config: { title, width, height, debug, html, url }, plugins }
}

///|
pub fn App::run(self : App) -> Unit {
  let webview = @webview.WebView::new(debug=self.config.debug)
    ..set_title(self.config.title)
    ..set_size(self.config.width, self.config.height, @webview.SizeHint::None)
  match self.config {
    { url: Some(url), .. } => webview.navigate(url)
    { html: Some(html), .. } => webview.set_html(html)
    _ => ()
  }
  self.plugins.each(plugin => webview.install_plugin(plugin))
  webview.run()
}
