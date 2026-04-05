///|
pub struct WindowConfig {
  title : String
  width : Int
  height : Int
  debug : Int
  html : String?
  url : String?
} derive(Show, Eq)

///|
pub struct App {
  config : WindowConfig
  plugins : Array[@webview.Plugin]
}

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
  App::{ config: { title, width, height, debug, html, url }, plugins }
}

///|
pub fn App::run(self : App) -> Unit {
  let webview = @webview.WebView::new(debug=self.config.debug)
  webview.set_title(self.config.title)
  webview.set_size(
    self.config.width,
    self.config.height,
    @webview.SizeHint::None,
  )
  match self.config.url {
    Some(url) => webview.navigate(url)
    None =>
      match self.config.html {
        Some(html) => webview.set_html(html)
        None => webview.set_html(default_html(self.config.title))
      }
  }
  for plugin in self.plugins {
    webview.install_plugin(plugin)
  }
  webview.run()
}

///|
fn default_html(title : String) -> String {
  "<!doctype html><html><head><meta charset=\"utf-8\" /><title>\{title}</title><style>body{font-family:system-ui,sans-serif;margin:0;min-height:100vh;display:grid;place-items:center;background:#f5f1e8;color:#1f2937;}</style></head><body><main><h1>\{title}</h1><p>Lepus is ready.</p></main></body></html>"
}
