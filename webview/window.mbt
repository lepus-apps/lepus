///|
/// High-level managed app that owns the parent dispatcher and child webview
/// process lifecycle.
pub struct Window {
  label : String
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
  position : (Int, Int)
  hidden : Bool
  focused : Bool
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
#alias(new, deprecated="Use `Window()` instead")
pub fn Window::Window(
  label? : String = "",
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
  position? : (Int, Int) = (-1, -1),
  hidden? : Bool = false,
  focused? : Bool = true,
  enable_window_controls_plugin? : Bool = true,
) -> Window {
  {
    label,
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
    position,
    hidden,
    focused,
    enable_window_controls_plugin,
    html: "",
    pending_custom_protocols: [],
    runtime_window_id: -1,
    plugins: [],
    size_hint,
  }
}

///|
/// Returns the stable label used for cross-window addressing.
/// Falls back to the `title` when no explicit label was provided.
pub fn Window::label(self : Window) -> String {
  if self.label.is_empty() {
    self.title
  } else {
    self.label
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
    ignore(
      @window_manager.wm_set_traffic_light_position(
        self.runtime_window_id,
        x,
        y,
      ),
    )
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
    ignore(
      @window_manager.wm_set_html(
        self.runtime_window_id,
        @encoding/utf8.encode(html),
      ),
    )
  }
}

///|
pub fn Window::navigate(self : Window, url : String) -> Unit {
  self.url = url
  if self.runtime_window_id > 0 {
    ignore(
      @window_manager.wm_navigate(
        self.runtime_window_id,
        @encoding/utf8.encode(url),
      ),
    )
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
  let args = @env.args()
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
/// Encodes a unique child-process marker used to carry a globally-unique
/// window-id `base` and a stable `label` across a re-exec`ed child process.
pub fn child_arg_for(base : Int, label : String) -> String {
  "--lepus-child:" + base.to_string() + ":" + label
}

///|
/// Detects whether the current process was spawned as a Lepus multi-window
/// child.
///
/// Returns `(window_id_base, label)` when argv carries a
/// `--lepus-child:<base>:<label>` marker, otherwise `None`.
pub fn detect_child_window() -> (Int, String)? {
  let prefix = "--lepus-child:"
  let args = @env.args()
  for arg in args {
    if arg.has_prefix(prefix) {
      let body = arg[prefix.length():]
      match body.find(":") {
        Some(idx) => {
          let base_str = body[:idx]
          let parsed = @string.parse_int(base_str) catch { _ => return None }
          let label = body[idx + 1:].to_owned()
          return Some((parsed, label))
        }
        None => ()
      }
    }
  }
  None
}

///|
/// Runs this window in the current (already-spawned, child) process.
///
/// Connects to the main-process IPC server, sets the globally-unique
/// window-id base, then creates and runs the webview. This is the child-side
/// half of `Window::run_many`.
pub async fn Window::run_child(self : Window, window_id_base : Int) -> Unit {
  guard WindowManager::connect_child_process() == 0 else {
    abort("Window::run_child: connect child process failed")
  }
  let wm = WindowManager::init(is_main=false)
  guard wm.set_window_id_base(window_id_base) == 0 else {
    abort("Window::run_child: set window id base failed")
  }
  self.run_child_async()
}

///|
/// Runs a multi-window app: spawns one child process per window (each with a
/// globally-unique window-id base and stable label), then serves commands from
/// all children until every window closes.
///
/// `labels` order must match the window order the child sides use to resolve
/// their own configuration via `detect_child_window()`.
pub async fn Window::run_many(
  labels : Array[String],
  router : ProcessCommandRouter,
) -> Unit {
  guard labels.length() > 0 else {
    abort("Window::run_many requires at least one window")
  }
  let args = @env.args()
  guard args.length() > 0 else { abort("Window::run_many: missing argv[0]") }
  let wm = WindowManager::init(is_main=true)
  let children : Array[Int] = []
  let mut base = 1
  for label in labels {
    let pid = wm.spawn_process(args[0], child_arg_for(base, label))
    guard pid > 0 else {
      abort("Window::run_many: spawn child for " + label + " failed")
    }
    children.push(pid)
    base = base + 1
  }
  router.serve_many(wm, children)
}

///|
/// Builds a main-process command router from an App-level plugin list.
pub fn build_router(plugins : Array[Plugin]) -> ProcessCommandRouter {
  let router = ProcessCommandRouter::new()
  for plugin in plugins {
    router.plugin(plugin.name, plugin_router => {
      for install in plugin.parent_installers {
        install(plugin_router)
      }
    })
  }
  router
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
      position=self.position,
      hidden=self.hidden,
      focused=self.focused,
    )
    self.runtime_window_id = webview.window_id()
    // macOS：安装标准主菜单，使 Cmd+W/Q/M 及 Edit 系列快捷键生效
    //（Cocoa 快捷键全由主菜单驱动）。激活策略沿用 vendor 默认的 Regular，
    // 保证窗口能被激活为 key window 并接收键盘事件。
    ignore(@window_manager.wm_install_default_app_menu())
    // 向主进程注册本窗口：主进程据 source_window_id 建立
    // `window_id -> 子进程 fd` 映射，从而能定向 push 事件到本窗口。
    let _reg = wm.broadcast(
      self.runtime_window_id,
      "window_registered",
      "{\"window_id\":" + self.runtime_window_id.to_string() + "}",
    )
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
/// Payload for the native window move command.
priv struct MoveRequest {
  x : Int
  y : Int
} derive(ToJson, FromJson)

///|
/// Payload for the native window resize command.
priv struct ResizeRequest {
  width : Int
  height : Int
} derive(ToJson, FromJson)

///|
/// Builds the `window_controls` plugin bound to `window_id`, exposing
/// close/minimize/maximize/fullscreen/drag commands to JavaScript.
pub fn window_controls_plugin(window_id : Int) -> Plugin {
  Plugin::Plugin("window_controls", plugin => {
    plugin.command_sync("close", (_ : Json) => {
      @window_manager.wm_close_window(window_id) == 0
    })
    plugin.command("minimize", (_ : Json) => {
      @window_manager.wm_minimize_window(window_id) == 0
    })
    plugin.command("maximize", (_ : Json) => {
      @window_manager.wm_maximize_window(window_id) == 0
    })
    plugin.command("unmaximize", (_ : Json) => {
      @window_manager.wm_unmaximize_window(window_id) == 0
    })
    plugin.command("toggle_maximize", (_ : Json) => {
      @window_manager.wm_toggle_maximize_window(window_id) == 0
    })
    plugin.command("set_fullscreen_on", (_ : Json) => {
      @window_manager.wm_set_fullscreen_window(window_id, 1) == 0
    })
    plugin.command("set_fullscreen_off", (_ : Json) => {
      @window_manager.wm_set_fullscreen_window(window_id, 0) == 0
    })
    plugin.command("toggle_fullscreen", (_ : Json) => {
      @window_manager.wm_toggle_fullscreen_window(window_id) == 0
    })
    plugin.command_sync("start_drag", (_ : Json) => {
      @window_manager.wm_start_drag_window(window_id) == 0
    })
    plugin.command("set_position", (req : MoveRequest) => {
      @window_manager.wm_set_position(window_id, req.x, req.y) == 0
    })
    plugin.command("set_size", (req : ResizeRequest) => {
      wm_set_size(window_id, req.width, req.height, None) == 0
    })
    plugin.command("show", (_ : Json) => {
      @window_manager.wm_set_visibility(window_id, 1) == 0
    })
    plugin.command("hide", (_ : Json) => {
      @window_manager.wm_set_visibility(window_id, 0) == 0
    })
    plugin.command("focus", (_ : Json) => {
      @window_manager.wm_focus_window(window_id) == 0
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
        #|  const callArgs = (name, arg) => {
        #|    const api = window.lepusApi?.window_controls?.[name];
        #|    if (typeof api !== 'function') return Promise.resolve(false);
        #|    return api(arg).catch(() => false);
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
        #|    setPosition: (x, y) => callArgs('set_position', { x, y }),
        #|    setSize: (width, height) => callArgs('set_size', { width, height }),
        #|    show: () => call('show'),
        #|    hide: () => call('hide'),
        #|    focus: () => call('focus'),
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
        #|  // Cross-window control: the main-process `windows` plugin pushes a directed
        #|  // `lepus:window` event (via the IPC event bus) so THIS window performs the
        #|  // native operation in its own process. This is what makes commands like
        #|  // `lepusApi.windows.focus/show/hide(...)` work for child-process windows.
        #|  window.addEventListener('lepus_event', (e) => {
        #|    const d = e && e.detail;
        #|    if (!d || d.event !== 'lepus:window') return;
        #|    const p = d.payload || {};
        #|    const fn = window.LepusWindow && window.LepusWindow[p.op];
        #|    if (typeof fn === 'function') fn.apply(null, Array.isArray(p.args) ? p.args : []);
        #|  });
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
  ignore(@window_manager.wm_minimize_window(window_id))
}

///|
/// Maximize native window.
pub fn Window::maximize(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_maximize_window(window_id))
}

///|
/// Restore native window from maximized state.
pub fn Window::unmaximize(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_unmaximize_window(window_id))
}

///|
/// Toggle native maximize state.
pub fn Window::toggle_maximize(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_toggle_maximize_window(window_id))
}

///|
/// Set native fullscreen state.
pub fn Window::set_fullscreen(self : Window, fullscreen : Bool) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(
    @window_manager.wm_set_fullscreen_window(
      window_id,
      if fullscreen {
        1
      } else {
        0
      },
    ),
  )
}

///|
/// Toggle native fullscreen state.
pub fn Window::toggle_fullscreen(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_toggle_fullscreen_window(window_id))
}

///|
/// Start native window drag/move gesture.
pub fn Window::start_drag(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_start_drag_window(window_id))
}

///|
/// Move the native window to an absolute screen position.
pub fn Window::set_position(self : Window, x : Int, y : Int) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_set_position(window_id, x, y))
}

///|
/// Resize the native window.
pub fn Window::set_size(
  self : Window,
  width : Int,
  height : Int,
  hint? : SizeHint = None,
) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(wm_set_size(window_id, width, height, hint))
}

///|
/// Show the native window.
pub fn Window::show(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_set_visibility(window_id, 1))
}

///|
/// Hide the native window.
pub fn Window::hide(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_set_visibility(window_id, 0))
}

///|
/// Bring the native window to front and focus it. On macOS this also activates
/// the owning process as the foreground app (Tauri `Window::set_focus` parity).
pub fn Window::focus(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_focus_window(window_id))
}

///|
/// Close native window.
pub fn Window::close(self : Window) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_close_window(window_id))
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
  let host = PluginHost::PluginHost(webview)
  if self.enable_window_controls_plugin {
    host.install(window_controls_plugin(webview.window_id()))
  }
  for plugin in self.plugins {
    host.install(plugin, proxy=Some(proxy))
  }
}

///|
pub fn Window::eval(self : Window, js : String) -> Unit {
  let window_id = self.require_runtime_window_id()
  ignore(@window_manager.wm_eval_js(window_id, @encoding/utf8.encode(js)))
}

///|
fn Window::require_runtime_window_id(self : Window) -> Int {
  guard self.runtime_window_id > 0 else {
    abort("Window API requires a running child webview process")
  }
  self.runtime_window_id
}
