///|
using @webview {type TrafficLightPosition}

///|
pub enum TitleBarStyle {
  Default = 0
  Hidden = 1
} derive(Debug, Eq, ToJson, FromJson, Hash)

///|

///|
pub struct WindowConfig {
  title : String
  width : Int
  height : Int
  debug : Int
  frameless : Bool
  resizable : Bool
  always_on_top : Bool
  transparent : Bool
  title_bar_style : TitleBarStyle
  title_bar_overlay : Bool
  traffic_light_position : TrafficLightPosition
  html : String?
  url : String?
} derive(Debug, Eq, ToJson, FromJson, Hash)

///|
pub fn WindowConfig::new(
  title? : String = "Lepus App",
  width? : Int = 800,
  height? : Int = 600,
  debug? : Int = 0,
  frameless? : Bool = false,
  resizable? : Bool = true,
  always_on_top? : Bool = false,
  transparent? : Bool = false,
  title_bar_style? : TitleBarStyle = TitleBarStyle::Default,
  title_bar_overlay? : Bool = false,
  traffic_light_position? : TrafficLightPosition = { x: -1, y: -1 },
  html? : String,
  url? : String,
) -> WindowConfig {
  {
    title,
    width,
    height,
    debug,
    frameless,
    resizable,
    always_on_top,
    transparent,
    title_bar_style,
    title_bar_overlay,
    traffic_light_position,
    html,
    url,
  }
}

///|
pub struct App {
  windows : Array[WindowConfig]
  plugins : Array[@webview.Plugin]
}

///|
pub struct Window {
  config : WindowConfig
  plugins : Array[@webview.Plugin]
}

///|
pub fn Window::new(
  title? : String = "Lepus App",
  width? : Int = 800,
  height? : Int = 600,
  debug? : Int = 0,
  frameless? : Bool = false,
  resizable? : Bool = true,
  always_on_top? : Bool = false,
  transparent? : Bool = false,
  title_bar_style? : TitleBarStyle = TitleBarStyle::Default,
  title_bar_overlay? : Bool = false,
  traffic_light_position? : TrafficLightPosition = { x: -1, y: -1 },
  html? : String,
  url? : String,
  plugins? : Array[@webview.Plugin] = [],
) -> Window {
  {
    config: {
      title,
      width,
      height,
      debug,
      frameless,
      resizable,
      always_on_top,
      transparent,
      title_bar_style,
      title_bar_overlay,
      traffic_light_position,
      html,
      url,
    },
    plugins,
  }
}

///|
pub fn Window::run(self : Window) -> Unit {
  App::new([self.config], plugins=self.plugins).run()
}

///|
pub fn App::new(
  windows : Array[WindowConfig],
  plugins? : Array[@webview.Plugin] = [],
) -> App {
  { windows, plugins }
}

///|
pub fn App::with_windows(
  windows : Array[WindowConfig],
  plugins? : Array[@webview.Plugin] = [],
) -> App {
  guard windows.length() > 0 else {
    abort("App::with_windows requires at least one window")
  }
  { windows, plugins }
}

///|
pub fn App::add_window(self : App, config : WindowConfig) -> Unit {
  self.windows.push(config)
}

///|
pub fn App::window_count(self : App) -> Int {
  self.windows.length()
}

///|
pub fn App::run(self : App, window_index? : Int = 0) -> Unit {
  guard window_index >= 0 && window_index < self.windows.length() else {
    abort("App::run window_index out of range")
  }
  let config = self.windows[window_index]
  let window = @webview.Window::new(
    title=config.title,
    width=config.width,
    height=config.height,
    debug=config.debug,
    frameless=config.frameless,
    resizable=config.resizable,
    always_on_top=config.always_on_top,
    transparent=config.transparent,
    title_bar_style=match config.title_bar_style {
      TitleBarStyle::Default => @webview.TitleBarStyle::Default
      TitleBarStyle::Hidden => @webview.TitleBarStyle::Hidden
    },
    title_bar_overlay=config.title_bar_overlay,
    traffic_light_position=config.traffic_light_position,
  )
  match config {
    { url: Some(url), .. } => window.navigate(url)
    { html: Some(html), .. } => window.set_html(html)
    _ => ()
  }
  self.plugins.each(plugin => window.install(plugin))
  window.run()
}
