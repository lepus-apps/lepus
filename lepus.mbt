///|
pub struct WindowConfig {
  title : String
  width : Int
  height : Int
  debug : Int
  frameless : Bool
  resizable : Bool
  always_on_top : Bool
  html : String?
  url : String?
} derive(Debug, Eq, ToJson, FromJson, Hash)

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
  frameless? : Bool = false,
  resizable? : Bool = true,
  always_on_top? : Bool = false,
  html? : String,
  url? : String,
  plugins? : Array[@webview.Plugin] = [],
) -> App {
  {
    config: {
      title,
      width,
      height,
      debug,
      frameless,
      resizable,
      always_on_top,
      html,
      url,
    },
    plugins,
  }
}

///|
pub fn App::run(self : App) -> Unit {
  let window = @webview.Window::new(
    title=self.config.title,
    width=self.config.width,
    height=self.config.height,
    debug=self.config.debug,
    customization={
      frameless: self.config.frameless,
      resizable: self.config.resizable,
      always_on_top: self.config.always_on_top,
    },
  )
  match self.config {
    { url: Some(url), .. } => window.navigate(url)
    { html: Some(html), .. } => window.set_html(html)
    _ => ()
  }
  self.plugins.each(plugin => window.install(plugin))
  window.run()
}
