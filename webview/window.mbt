///|
/// High-level managed app that owns the parent dispatcher and child webview
/// process lifecycle.
pub struct Window {
  title : String
  width : Int
  height : Int
  size_hint : SizeHint
  debug : Int
  devtools : Bool
  child_arg : String
  mut frameless : Bool
  mut resizable : Bool
  mut closeable : Bool
  mut always_on_top : Bool
  mut transparent : Bool
  mut title_bar_style : TitleBarStyle
  mut title_bar_overlay : Bool
  mut traffic_light_position : (Int, Int)
  enable_window_controls_plugin : Bool
  mut url : String
  mut html : String
  pending_custom_protocols : Array[(String, String)]
  mut runtime_window_id : Int
  plugins : Array[Plugin]
}

///|
/// Creates a managed app. The library handles the parent dispatcher and child
/// webview process automatically.
pub fn Window::new(
  title? : String = "MoonBit WebView",
  url? : String = "",
  width? : Int = 800,
  height? : Int = 600,
  size_hint? : SizeHint = None,
  debug? : Int = 0,
  devtools? : Bool = false,
  child_arg? : String = "--moonbit-webview-child",
  frameless? : Bool = false,
  resizable? : Bool = true,
  closeable? : Bool = true,
  always_on_top? : Bool = false,
  transparent? : Bool = false,
  title_bar_style? : TitleBarStyle = Default,
  title_bar_overlay? : Bool = false,
  traffic_light_position? : (Int, Int) = (-1, -1),
  enable_window_controls_plugin? : Bool = true,
) -> Window {
  {
    title,
    url,
    width,
    height,
    debug,
    devtools,
    child_arg,
    frameless,
    resizable,
    closeable,
    always_on_top,
    transparent,
    title_bar_style,
    title_bar_overlay,
    traffic_light_position,
    enable_window_controls_plugin,
    html: "",
    pending_custom_protocols: [],
    runtime_window_id: -1,
    plugins: [],
    size_hint,
  }
}

///|
/// Applies native custom-window style flags.
pub fn Window::set_window_customization(
  self : Window,
  frameless : Bool,
  resizable : Bool,
  closeable : Bool,
  always_on_top : Bool,
  transparent : Bool,
  title_bar_style : TitleBarStyle,
  title_bar_overlay : Bool,
) -> Unit {
  self.frameless = frameless
  self.resizable = resizable
  self.closeable = closeable
  self.always_on_top = always_on_top
  self.transparent = transparent
  self.title_bar_style = title_bar_style
  self.title_bar_overlay = title_bar_overlay
  if self.runtime_window_id > 0 {
    ignore(
      wm_set_window_customization(
        self.runtime_window_id,
        if frameless {
          1
        } else {
          0
        },
        if resizable {
          1
        } else {
          0
        },
        if closeable {
          1
        } else {
          0
        },
        if always_on_top {
          1
        } else {
          0
        },
        if transparent {
          1
        } else {
          0
        },
        title_bar_style,
        if title_bar_overlay {
          1
        } else {
          0
        },
      ),
    )
  }
}

///|
/// Set macOS traffic-light buttons position.
pub fn Window::set_traffic_light_position(
  self : Window,
  x : Int,
  y : Int,
) -> Unit {
  self.traffic_light_position = (x, y)
  if self.runtime_window_id > 0 {
    ignore(wm_set_traffic_light_position(self.runtime_window_id, x, y))
  }
}

///|
/// Installs a managed plugin into the app.
pub fn Window::install(self : Window, plugin : Plugin) -> Unit {
  self.plugins.push(plugin)
}

///|
/// Sets inline HTML content for the child webview.
pub fn Window::set_html(self : Window, html : String) -> Unit {
  self.html = html
  if self.runtime_window_id > 0 {
    ignore(wm_set_html(self.runtime_window_id, @encoding/utf8.encode(html)))
  }
}

///|
pub fn Window::navigate(self : Window, url : String) -> Unit {
  self.url = url
  if self.runtime_window_id > 0 {
    ignore(wm_navigate(self.runtime_window_id, @encoding/utf8.encode(url)))
  }
}

///|
/// Register a custom scheme for the child webview before it navigates.
pub fn Window::set_custom_protocol(
  self : Window,
  scheme : String,
  root_dir : String,
) -> Unit {
  self.pending_custom_protocols.push((scheme, root_dir))
}

///|
/// Runs the managed app end-to-end.
pub async fn Window::run(self : Window) -> Unit {
  let args = @sys.get_cli_args()
  if args.length() > 1 && args[1] == self.child_arg {
    guard WindowManager::connect_child_process() == 0 else {
      abort("ManagedApp::run: connect child process failed")
    }
    self.run_child_async()
    return
  }
  let wm = WindowManager::init()
  guard args.length() > 0 else { abort("ManagedApp::run: missing argv[0]") }
  let child_pid = wm.spawn_process(args[0], self.child_arg)
  guard child_pid > 0 else {
    abort("ManagedApp::run: spawn webview process failed")
  }
  self.build_router().serve(wm, child_pid)
}

///|
async fn Window::run_child_async(self : Window) -> Unit {
  @async.with_task_group(task_group => {
    let wm = WindowManager::init(is_main=false)
    let webview = WebView::new_managed(
      task_group,
      title=self.title,
      url="",
      width=self.width,
      height=self.height,
      debug=self.debug,
      devtools=self.devtools,
      frameless=self.frameless,
      resizable=self.resizable,
      closeable=self.closeable,
      always_on_top=self.always_on_top,
      transparent=self.transparent,
      title_bar_style=self.title_bar_style,
      title_bar_overlay=self.title_bar_overlay,
      traffic_light_position=self.traffic_light_position,
    )
    self.runtime_window_id = webview.window_id()
    self.pending_custom_protocols.each(mapping => {
      let (scheme, root_dir) = mapping
      webview.set_custom_protocol(scheme, root_dir)
    })
    self.install_child_plugins(webview, wm)
    if self.frameless ||
      self.title_bar_style == Hidden ||
      self.title_bar_overlay {
      webview.enable_custom_titlebar_support()
    }
    if self.transparent {
      webview.enable_transparent_background_support()
    }
    if self.traffic_light_position.0 >= 0 && self.traffic_light_position.1 >= 0 {
      webview.set_traffic_light_position(
        self.traffic_light_position.0,
        self.traffic_light_position.1,
      )
    }
    if self.url != "" {
      webview.navigate(self.url)
    }
    if self.html != "" {
      webview.set_html(self.html)
    }
    webview.run()
  })
}

///|
fn Window::window_controls_plugin(_self : Window, window_id : Int) -> Plugin {
  Plugin::new("window_controls", plugin => {
    plugin.command_sync("close", (_ : Json) => wm_close_window(window_id) == 0)
    plugin.command("minimize", (_ : Json) => wm_minimize_window(window_id) == 0)
    plugin.command("maximize", (_ : Json) => wm_maximize_window(window_id) == 0)
    plugin.command("unmaximize", (_ : Json) => {
      wm_unmaximize_window(window_id) == 0
    })
    plugin.command("toggle_maximize", (_ : Json) => {
      wm_toggle_maximize_window(window_id) == 0
    })
    plugin.command("set_fullscreen_on", (_ : Json) => {
      wm_set_fullscreen_window(window_id, 1) == 0
    })
    plugin.command("set_fullscreen_off", (_ : Json) => {
      wm_set_fullscreen_window(window_id, 0) == 0
    })
    plugin.command("toggle_fullscreen", (_ : Json) => {
      wm_toggle_fullscreen_window(window_id) == 0
    })
    plugin.command_sync("start_drag", (_ : Json) => {
      wm_start_drag_window(window_id) == 0
    })
    plugin.script(
      (
        #|(() => {
        #|  if (window.__LEPUS_WINDOW_CONTROL_READY__) return;
        #|  const call = (name) => {
        #|    const api = window.lepusApi?.window_controls?.[name];
        #|    if (typeof api !== 'function') return Promise.resolve(false);
        #|    return api(null).catch(() => false);
        #|  };
        #|  const originalClose = typeof window.close === 'function' ? window.close.bind(window) : null;
        #|  window.close = () => { call('close'); };
        #|  window.LepusWindow = {
        #|    close: () => call('close'),
        #|    minimize: () => call('minimize'),
        #|    maximize: () => call('maximize'),
        #|    unmaximize: () => call('unmaximize'),
        #|    toggleMaximize: () => call('toggle_maximize'),
        #|    setFullscreen: (v) => call(v ? 'set_fullscreen_on' : 'set_fullscreen_off'),
        #|    toggleFullscreen: () => call('toggle_fullscreen'),
        #|    startDrag: () => call('start_drag'),
        #|    _originalClose: originalClose,
        #|  };
        #|  const hasDragRegion = (el) => {
        #|    let cur = el;
        #|    while (cur) {
        #|      if (cur.matches && cur.matches('.lepus-no-drag,[data-lepus-no-drag=\"true\"]')) return false;
        #|      if (cur.matches && cur.matches('.lepus-drag,.lepus-titlebar,[data-lepus-drag=\"true\"]')) return true;
        #|      const css = getComputedStyle(cur).getPropertyValue('-webkit-app-region').trim();
        #|      if (css === 'no-drag') return false;
        #|      if (css === 'drag') return true;
        #|      cur = cur.parentElement;
        #|    }
        #|    return false;
        #|  };
        #|  document.addEventListener('mousedown', (event) => {
        #|    if (event.button !== 0) return;
        #|    const target = event.target;
        #|    if (!(target instanceof Element)) return;
        #|    if (!hasDragRegion(target)) return;
        #|    call('start_drag');
        #|  }, true);
        #|  window.__LEPUS_WINDOW_CONTROL_READY__ = true;
        #|})();
      ),
    )
  })
}

///|
/// Minimize native window.
pub fn Window::minimize(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_minimize_window(window_id))
}

///|
/// Maximize native window.
pub fn Window::maximize(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_maximize_window(window_id))
}

///|
/// Restore native window from maximized state.
pub fn Window::unmaximize(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_unmaximize_window(window_id))
}

///|
/// Toggle native maximize state.
pub fn Window::toggle_maximize(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_toggle_maximize_window(window_id))
}

///|
/// Set native fullscreen state.
pub fn Window::set_fullscreen(self : Window, fullscreen : Bool) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_set_fullscreen_window(window_id, if fullscreen { 1 } else { 0 }))
}

///|
/// Toggle native fullscreen state.
pub fn Window::toggle_fullscreen(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_toggle_fullscreen_window(window_id))
}

///|
/// Start native window drag/move gesture.
pub fn Window::start_drag(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_start_drag_window(window_id))
}

///|
/// Close native window.
pub fn Window::close(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_close_window(window_id))
}

///|
fn Window::build_router(self : Window) -> ProcessCommandRouter {
  let router = ProcessCommandRouter::new()
  for plugin in self.plugins {
    router.plugin(plugin.name, plugin_router => {
      for install in plugin.parent_installers {
        install(plugin_router)
      }
    })
  }
  router
}

///|
fn Window::install_child_plugins(
  self : Window,
  webview : WebView[Unit],
  wm : WindowManager,
) -> Unit {
  let proxy = ProcessCommandProxy::new(wm, webview.window_id())
  let host = PluginHost::new(webview)
  if self.enable_window_controls_plugin {
    host.install(self.window_controls_plugin(webview.window_id()))
  }
  for plugin in self.plugins {
    host.install(plugin, proxy=Some(proxy))
  }
}

///|
pub fn Window::eval(self : Window, js : String) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_eval_js(window_id, @encoding/utf8.encode(js)))
}

///|
fn Window::require_runtime_window_id(self : Window) -> Int {
  guard self.runtime_window_id > 0 else {
    abort("Window API requires a running child webview process")
  }
  self.runtime_window_id
}
