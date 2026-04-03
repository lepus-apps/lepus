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
} derive(Show, Eq)

///|
pub struct Builder {
  mut config : WindowConfig
}

///|
pub fn Builder::new() -> Builder {
  Builder::{
    config: {
      title: "Lepus App",
      width: 800,
      height: 600,
      debug: 0,
      html: None,
      url: None,
    },
  }
}

///|
pub fn Builder::title(self : Builder, title : String) -> Builder {
  self.config = { ..self.config, title, }
  self
}

///|
pub fn Builder::size(self : Builder, width : Int, height : Int) -> Builder {
  self.config = { ..self.config, width, height }
  self
}

///|
pub fn Builder::debug(self : Builder, debug : Int) -> Builder {
  self.config = { ..self.config, debug, }
  self
}

///|
pub fn Builder::html(self : Builder, html : String) -> Builder {
  self.config = { ..self.config, html: Some(html), url: None }
  self
}

///|
pub fn Builder::url(self : Builder, url : String) -> Builder {
  self.config = { ..self.config, url: Some(url), html: None }
  self
}

///|
pub fn Builder::build(self : Builder) -> App {
  App::{ config: self.config }
}

///|
pub fn App::run(self : App) -> Unit {
  let webview = @lepus_runtime_webview.Webview::new(debug=self.config.debug)
  webview.set_title(self.config.title)
  webview.set_size(
    self.config.width,
    self.config.height,
    @lepus_runtime_webview.SizeHint::None,
  )
  match self.config.url {
    Some(url) => webview.navigate(url)
    None =>
      match self.config.html {
        Some(html) => webview.set_html(html)
        None => webview.set_html(default_html(self.config.title))
      }
  }
  webview.run()
}

///|
pub fn default_app() -> Builder {
  Builder::new()
}

///|
fn default_html(title : String) -> String {
  "<!doctype html><html><head><meta charset=\"utf-8\" /><title>" +
  title +
  "</title><style>body{font-family:system-ui,sans-serif;margin:0;min-height:100vh;display:grid;place-items:center;background:#f5f1e8;color:#1f2937;}</style></head><body><main><h1>" +
  title +
  "</h1><p>Lepus is ready.</p></main></body></html>"
}
