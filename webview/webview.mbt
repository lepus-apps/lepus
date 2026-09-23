///|
/// Window size hints
pub(all) enum SizeHint {
  /// Width and height are default size.
  None = 0
  /// Width and height are minimum bounds.
  Min = 1
  /// Width and height are maximum bounds.
  Max = 2
  /// Window size can not be changed by a user.
  Fixed = 3
}

///|
/// An instance of a webview window (managed via IPC).
///
/// Example:
///
/// ```moonbit nocheck
/// let webview = @webview.WebView::new_managed(task_group)
/// webview.set_title("My WebView")
/// webview.set_size(800, 600, @webview.SizeHint::None)
/// webview.set_html("<html><body><h1>Hello, World!</h1></body></html>")
/// webview.terminate()
/// ```
struct WebView[X] {
  handle : WebView_t
  window_id : Int
  task_group : @async.TaskGroup[X]
}

// ── Internal logging ──────────────────────────────────────────────────────────
//
// log_level controls verbosity of internal [bridge] / [plugin] traces:
//   0  silent  (default)
//   1  info    key lifecycle events (command registered, dispatch invoked,
//              response sent)
//   2  verbose full payloads and handler results
//
// Set automatically by WebView::new_managed(debug=1).  Can also be adjusted at
// runtime via set_log_level().

///|
let webview_log_level : Ref[Int] = { val: 0 }

///|
/// Set the internal log verbosity.
///
/// - `0` — silent (default)
/// - `1` — info: lifecycle events (registered commands, invocations, responses)
/// - `2` — verbose: full request/response payloads
fn set_log_level(level : Int) -> Unit {
  webview_log_level.val = level
}

///|
/// Emit a log line if `level` ≤ the current log level.
/// The prefix is always included so grep filtering works without extra tooling.
fn log(level : Int, msg : String) -> Unit {
  if level <= webview_log_level.val {
    println(msg)
  }
}

///|
/// Creates a managed webview window via native WindowManager (IPC-capable).
///
/// Window lifecycle operations (`terminate/set_title/set_size/`
/// `navigate/set_html/eval/init`) will be routed through `wm_*` APIs.
fn[X] WebView::new_managed(
  task_group : @async.TaskGroup[X],
  title? : String = "MoonBit WebView",
  url? : String = "",
  width? : Int = 800,
  height? : Int = 600,
  debug? : Int = 0,
  devtools? : Bool = false,
  frameless? : Bool = false,
  resizable? : Bool = true,
  closeable? : Bool = true,
  always_on_top? : Bool = false,
  transparent? : Bool = false,
  title_bar_style? : TitleBarStyle = Default,
  title_bar_overlay? : Bool = false,
  traffic_light_position? : (Int, Int) = (-1, -1),
) -> WebView[X] {
  let create_debug = if devtools && debug <= 0 { 1 } else { debug }
  let window_id = wm_create_window(
    @encoding/utf8.encode(title),
    @encoding/utf8.encode(url),
    width,
    height,
    -1,
    -1,
    0,
    create_debug,
    -1,
  )
  guard window_id > 0 else {
    abort("WebView::new_managed failed: wm_create_window")
  }
  let handle = wm_get_handle(window_id)
  if create_debug > 0 {
    set_log_level(create_debug)
  }
  if devtools {
    ignore(wm_set_devtools(window_id, 1))
  }
  ignore(
    wm_set_window_customization(
      window_id,
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
  if traffic_light_position.0 >= 0 && traffic_light_position.1 >= 0 {
    ignore(
      wm_set_traffic_light_position(
        window_id,
        traffic_light_position.0,
        traffic_light_position.1,
      ),
    )
  }
  { handle, window_id, task_group }
}

///|
/// Destroys the webview and closes the window.
/// Safe to call from a background thread.
pub fn[X] WebView::destroy(self : WebView[X]) -> Unit {
  ignore(wm_destroy_window(self.window_id))
}

///|
/// Stops the main event loop.
/// Safe to call from a background thread.
pub fn[X] WebView::terminate(self : WebView[X]) -> Unit {
  ignore(wm_terminate_window(self.window_id))
}

///|
/// Updates the title of the native window.
pub fn[X] WebView::set_title(self : WebView[X], title : String) -> Unit {
  ignore(wm_set_title(self.window_id, @encoding/utf8.encode(title)))
}

///|
/// Loads HTML content into the webview.
///
/// Example:
/// ```moonbit nocheck
/// let webview = @webview.WebView::new_managed(task_group)
/// webview.set_html("<html><body><h1>Hello, World!</h1></body></html>")
/// webview.terminate()
/// ```
pub fn[X] WebView::set_html(self : WebView[X], html : String) -> Unit {
  ignore(wm_set_html(self.window_id, @encoding/utf8.encode(html)))
}

///|
/// Register a custom scheme backed by a local root directory for this webview.
pub fn[X] WebView::set_custom_protocol(
  self : WebView[X],
  scheme : String,
  root_dir : String,
) -> Unit {
  ignore(
    webview_set_custom_protocol(
      self.handle,
      @encoding/utf8.encode(scheme),
      @encoding/utf8.encode(root_dir),
    ),
  )
}

///|
/// Navigates the webview to the given URL. URL may be a data URI.
///
/// Example:
/// ```moonbit nocheck
/// let webview = @webview.WebView::new_managed(task_group)
/// webview.navigate("https://www.example.com")
/// webview.navigate("data:text/html,<h1>Hello</h1>")
/// webview.terminate()
/// ```
pub fn[X] WebView::navigate(self : WebView[X], url : String) -> Unit {
  ignore(wm_navigate(self.window_id, @encoding/utf8.encode(url)))
}

///|
/// Navigates one step back in browser history.
pub fn[X] WebView::back(self : WebView[X]) -> Unit {
  self.eval("history.back();")
}

///|
/// Navigates one step forward in browser history.
pub fn[X] WebView::forward(self : WebView[X]) -> Unit {
  self.eval("history.forward();")
}

///|
/// Navigates to a specific entry in browser history.
///
/// - `delta < 0`: backward
/// - `delta > 0`: forward
/// - `delta = 0`: reload current entry
pub fn[X] WebView::go(self : WebView[X], delta : Int) -> Unit {
  self.eval("history.go(\{delta});")
}

///|
/// Reloads the current page using standard browser cache policy.
pub fn[X] WebView::reload(self : WebView[X]) -> Unit {
  self.eval("window.location.reload();")
}

///|
/// Reloads the current page and requests a revalidation from server.
pub fn[X] WebView::reload_force(self : WebView[X]) -> Unit {
  self.eval("window.location.reload(true);")
}

///|
/// Returns the raw `WebView_t` handle.
pub fn[X] WebView::get_handle(self : WebView[X]) -> WebView_t {
  self.handle
}

///|
/// Returns the managed window id.
fn[X] WebView::window_id(self : WebView[X]) -> Int {
  self.window_id
}

///|
/// Evaluates arbitrary JavaScript code.
fn[X] WebView::eval(self : WebView[X], js : String) -> Unit {
  ignore(wm_eval_js(self.window_id, @encoding/utf8.encode(js)))
}

///|
/// Injects JavaScript code executed immediately on every page load,
/// before `window.onload`.
fn[X] WebView::init(self : WebView[X], js : String) -> Unit {
  ignore(wm_init_js(self.window_id, @encoding/utf8.encode(js)))
}

///|
/// Updates the size of the native window.
///
/// Remarks:
/// - `SizeHint::Max` is not supported with GTK 4.
/// - GTK 4 can only set a default size early in the window lifecycle.
pub fn[X] WebView::set_size(
  self : WebView[X],
  width : Int,
  height : Int,
  hints : SizeHint,
) -> Unit {
  ignore(wm_set_size(self.window_id, width, height, hints))
}

///|
/// Applies native custom-window style flags at runtime.
pub fn[X] WebView::set_window_customization(
  self : WebView[X],
  frameless : Bool,
  resizable : Bool,
  closeable : Bool,
  always_on_top : Bool,
  transparent : Bool,
  title_bar_style : TitleBarStyle,
  title_bar_overlay : Bool,
) -> Unit {
  ignore(
    wm_set_window_customization(
      self.window_id,
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

///|
/// Set macOS traffic-light buttons position.
pub fn[X] WebView::set_traffic_light_position(
  self : WebView[X],
  x : Int,
  y : Int,
) -> Unit {
  ignore(wm_set_traffic_light_position(self.window_id, x, y))
}

///|
/// Injects CSS helper classes for Electron-like drag regions.
///
/// - `.lepus-drag`: draggable zone (`-webkit-app-region: drag`)
/// - `.lepus-titlebar`: titlebar draggable zone (`-webkit-app-region: drag`)
/// - `[data-lepus-drag="true"]`: draggable zone (`-webkit-app-region: drag`)
/// - `.lepus-no-drag`: interactive zone (`-webkit-app-region: no-drag`)
pub fn[X] WebView::enable_custom_titlebar_support(self : WebView[X]) -> Unit {
  self.init(
    (
      #|(() => {
      #|  if (window.__LEPUS_DRAG_STYLE__) return;
      #|  const style = document.createElement('style');
      #|  style.textContent = [
      #|    '.lepus-drag { -webkit-app-region: drag; app-region: drag; user-select: none; }',
      #|    '.lepus-titlebar { -webkit-app-region: drag; app-region: drag; user-select: none; }',
      #|    '[data-lepus-drag=\"true\"] { -webkit-app-region: drag; app-region: drag; user-select: none; }',
      #|    '.lepus-no-drag { -webkit-app-region: no-drag; app-region: no-drag; }',
      #|  ].join('');
      #|  document.documentElement.appendChild(style);
      #|  window.__LEPUS_DRAG_STYLE__ = true;
      #|})();
    ),
  )
}

///|
/// Injects CSS/JS that keeps page background transparent.
pub fn[X] WebView::enable_transparent_background_support(
  self : WebView[X],
) -> Unit {
  self.init(
    (
      #|(() => {
      #|  if (window.__LEPUS_TRANSPARENT_BG__) return;
      #|  const style = document.createElement('style');
      #|  style.textContent = [
      #|    'html, body { background: transparent !important; }',
      #|  ].join('');
      #|  document.documentElement.appendChild(style);
      #|  const apply = () => {
      #|    document.documentElement.style.background = 'transparent';
      #|    if (document.body) document.body.style.background = 'transparent';
      #|  };
      #|  apply();
      #|  if (document.readyState === 'loading') {
      #|    document.addEventListener('DOMContentLoaded', apply, { once: true });
      #|  }
      #|  window.__LEPUS_TRANSPARENT_BG__ = true;
      #|})();
    ),
  )
}

///|
/// Minimize native window.
pub fn[X] WebView::minimize(self : WebView[X]) -> Unit {
  ignore(wm_minimize_window(self.window_id))
}

///|
/// Maximize native window.
pub fn[X] WebView::maximize(self : WebView[X]) -> Unit {
  ignore(wm_maximize_window(self.window_id))
}

///|
/// Restore native window from maximized state.
pub fn[X] WebView::unmaximize(self : WebView[X]) -> Unit {
  ignore(wm_unmaximize_window(self.window_id))
}

///|
/// Toggle native maximize state.
pub fn[X] WebView::toggle_maximize(self : WebView[X]) -> Unit {
  ignore(wm_toggle_maximize_window(self.window_id))
}

///|
/// Set native fullscreen state.
pub fn[X] WebView::set_fullscreen(self : WebView[X], fullscreen : Bool) -> Unit {
  ignore(
    wm_set_fullscreen_window(self.window_id, if fullscreen { 1 } else { 0 }),
  )
}

///|
/// Toggle native fullscreen state.
pub fn[X] WebView::toggle_fullscreen(self : WebView[X]) -> Unit {
  ignore(wm_toggle_fullscreen_window(self.window_id))
}

///|
/// Start native window drag/move gesture.
pub fn[X] WebView::start_drag(self : WebView[X]) -> Unit {
  ignore(wm_start_drag_window(self.window_id))
}

///|
/// Close native window.
pub fn[X] WebView::close(self : WebView[X]) -> Unit {
  ignore(wm_close_window(self.window_id))
}

///|
/// Enable or disable developer tools integration at runtime.
pub fn[X] WebView::set_devtools(self : WebView[X], enabled : Bool) -> Unit {
  ignore(wm_set_devtools(self.window_id, if enabled { 1 } else { 0 }))
}

///|
/// Runs the main event loop until terminated, then destroys the webview.
fn[X] WebView::run(self : WebView[X]) -> Unit {
  ignore(wm_run_window(self.window_id))
  self.destroy()
}
