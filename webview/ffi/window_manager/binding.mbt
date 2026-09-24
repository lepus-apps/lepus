/// FFI declarations for the window-manager C runtime, co-located with their
/// implementations in this package's `stub.c` (the `g_wm` state machine: IPC
/// transport, window lifecycle, platform view control).
///
/// The `webview` package references these via `@window_manager.*`. Only the
/// two declarations whose parameter types depend on higher-level webview
/// enums (`wm_set_size`/`wm_set_window_customization`, taking `SizeHint` and
/// `TitleBarStyle`) remain in `lepus-apps/lepus/webview/binding.mbt`, since
/// moving them would create a package cycle.
///
/// Ownership rules (moonbit-c-binding skill):
///   #borrow(param) — C only reads the value during the call, does not store it.
///   #owned(param)  — ownership transfers to C; C must moonbit_decref when done.
/// Primitives (Int, Int64, Bool, …) are passed by value — no annotation needed.

///|
/// Pop the next queued IPC message encoded as:
/// source i32, target i32, type i32, id i32, subtype_len i32, data_len i32,
/// followed by subtype bytes and data bytes. Empty bytes means no message.
pub extern "C" fn wm_ipc_pop_message_wire(window_id : Int) -> Bytes = "moonbit_wm_ipc_pop_message_wire"

///|
/// Initialize native window manager runtime.
pub extern "C" fn wm_init(is_main_process : Int) -> Int = "moonbit_wm_init"

///|
/// Cleanup native window manager runtime.
pub extern "C" fn wm_cleanup() -> Unit = "moonbit_wm_cleanup"

///|
/// Create a managed native window and register it in WM.
#borrow(title, url)
pub extern "C" fn wm_create_window(
  title : Bytes,
  url : Bytes,
  width : Int,
  height : Int,
  x : Int,
  y : Int,
  has_x : Int,
  has_y : Int,
  parent_window_id : Int,
) -> Int = "moonbit_wm_create_window"

///|
/// Destroy managed window.
pub extern "C" fn wm_destroy_window(window_id : Int) -> Int = "moonbit_wm_destroy_window"

///|
/// Run managed window event loop.
pub extern "C" fn wm_run_window(window_id : Int) -> Int = "moonbit_wm_run_window"

///|
/// Start managed window event loop on a detached native thread.
pub extern "C" fn wm_run_window_async(window_id : Int) -> Int = "moonbit_wm_run_window_async"

///|
/// Request window termination.
pub extern "C" fn wm_terminate_window(window_id : Int) -> Int = "moonbit_wm_terminate_window"

///|
/// Set managed window title.
#borrow(title)
pub extern "C" fn wm_set_title(window_id : Int, title : Bytes) -> Int = "moonbit_wm_set_title"

///|
/// Move managed window to an absolute screen position (top-left origin on
/// Windows/Linux; bottom-left Cocoa origin on macOS).
pub extern "C" fn wm_set_position(window_id : Int, x : Int, y : Int) -> Int = "moonbit_wm_set_position"

///|
/// Set macOS traffic-light buttons position.
pub extern "C" fn wm_set_traffic_light_position(
  window_id : Int,
  x : Int,
  y : Int,
) -> Int = "moonbit_wm_set_traffic_light_position"

///|
/// Minimize native window.
pub extern "C" fn wm_minimize_window(window_id : Int) -> Int = "moonbit_wm_minimize_window"

///|
/// Maximize native window.
pub extern "C" fn wm_maximize_window(window_id : Int) -> Int = "moonbit_wm_maximize_window"

///|
/// Restore native window from maximized state.
pub extern "C" fn wm_unmaximize_window(window_id : Int) -> Int = "moonbit_wm_unmaximize_window"

///|
/// Toggle native maximize state.
pub extern "C" fn wm_toggle_maximize_window(window_id : Int) -> Int = "moonbit_wm_toggle_maximize_window"

///|
/// Set native fullscreen state.
pub extern "C" fn wm_set_fullscreen_window(
  window_id : Int,
  fullscreen : Int,
) -> Int = "moonbit_wm_set_fullscreen_window"

///|
/// Toggle native fullscreen state.
pub extern "C" fn wm_toggle_fullscreen_window(window_id : Int) -> Int = "moonbit_wm_toggle_fullscreen_window"

///|
/// Start native window drag/move gesture.
pub extern "C" fn wm_start_drag_window(window_id : Int) -> Int = "moonbit_wm_start_drag_window"

///|
/// Close native window.
pub extern "C" fn wm_close_window(window_id : Int) -> Int = "moonbit_wm_close_window"

///|
/// Bring a window to front and focus it (activates the app on macOS).
/// Mirrors Tauri's `Window::set_focus` / tao's `set_focus`.
pub extern "C" fn wm_focus_window(window_id : Int) -> Int = "moonbit_wm_focus_window"

///|
/// Enable or disable developer tools integration.
pub extern "C" fn wm_set_devtools(window_id : Int, enabled : Int) -> Int = "moonbit_wm_set_devtools"

///|
/// Set the NSApplication activation policy (macOS only).
/// 0 = Regular (shows Dock icon), 1 = Accessory, 2 = Prohibited (no Dock icon).
/// No-op on other platforms. Used so a multi-window app shows a single Dock
/// icon: the main process declares Regular, child window processes Prohibited.
pub extern "C" fn wm_set_activation_policy(policy : Int) -> Int = "moonbit_wm_set_activation_policy"

///|
/// Install the standard application main menu (macOS only) so that keyboard
/// shortcuts work: Cmd+Q (quit app), Cmd+W (close window), Cmd+M (minimize),
/// and the Edit menu (Cmd+Z/X/C/V/A) for text editing in WKWebView.
/// No-op on other platforms.
pub extern "C" fn wm_install_default_app_menu() -> Int = "moonbit_wm_install_default_app_menu"

///|
/// Navigate managed window to URL.
#borrow(url)
pub extern "C" fn wm_navigate(window_id : Int, url : Bytes) -> Int = "moonbit_wm_navigate"

///|
/// Set managed window HTML.
#borrow(html)
pub extern "C" fn wm_set_html(window_id : Int, html : Bytes) -> Int = "moonbit_wm_set_html"

///|
/// Eval JS in managed window.
#borrow(js)
pub extern "C" fn wm_eval_js(window_id : Int, js : Bytes) -> Int = "moonbit_wm_eval_js"

///|
/// Init JS in managed window.
#borrow(js)
pub extern "C" fn wm_init_js(window_id : Int, js : Bytes) -> Int = "moonbit_wm_init_js"

///|
/// Set managed window visibility.
pub extern "C" fn wm_set_visibility(window_id : Int, visible : Int) -> Int = "moonbit_webview_set_window_visibility"

///|
/// Get managed window visibility.
pub extern "C" fn wm_get_visibility(window_id : Int) -> Int = "moonbit_webview_get_window_visibility"

///|
/// Get native handle by managed window id.
pub extern "C" fn wm_get_handle(window_id : Int) -> @webview_sys.WebView_t = "moonbit_wm_get_handle"

///|
/// Respond to a JS binding call on the managed window UI thread.
#borrow(seq, result)
pub extern "C" fn wm_return_raw(
  window_id : Int,
  seq : Bytes,
  status : Int,
  result : Bytes,
) -> Int = "moonbit_wm_return_raw"

///|
/// Create child-process window.
#borrow(title, url)
pub extern "C" fn wm_create_child_window(
  title : Bytes,
  url : Bytes,
  width : Int,
  height : Int,
  parent_window_id : Int,
) -> Int = "moonbit_wm_create_child_window"

///|
/// Fork the current process into a child that is already connected to the IPC server.
/// Returns child pid in the parent process, `0` in the child process, and `-1` on error.
pub extern "C" fn wm_fork_process() -> Int = "moonbit_wm_fork_process"

///|
/// Spawn a fresh child process by executing the given program path with one extra argument.
#borrow(program, arg1)
pub extern "C" fn wm_spawn_process(program : Bytes, arg1 : Bytes) -> Int = "moonbit_wm_spawn_process"

///|
/// Connect the current process to the parent's IPC server and switch WM into child mode.
pub extern "C" fn wm_connect_child_process() -> Int = "moonbit_wm_connect_child_process"

///|
/// Set the current (child) process window-id starting base for globally unique id allocation.
pub extern "C" fn wm_set_window_id_base(base : Int) -> Int = "moonbit_wm_set_window_id_base"

///|
/// Get process type: 0 main, 1 child.
pub extern "C" fn wm_get_process_type() -> Int = "moonbit_wm_get_process_type"

///|
/// Get current process id.
pub extern "C" fn wm_get_process_id() -> Int = "moonbit_wm_get_process_id"

///|
/// Kill child process.
pub extern "C" fn wm_kill_child(pid : Int) -> Int = "moonbit_wm_kill_child"

///|
/// Non-blocking child wait. Returns child pid when exited, `0` when still running.
pub extern "C" fn wm_wait_child_noblock(pid : Int) -> Int = "moonbit_wm_wait_child_noblock_no_status"

///|
/// Send asynchronous IPC message.
#borrow(subtype, data)
pub extern "C" fn wm_ipc_send(
  source_window_id : Int,
  target_window_id : Int,
  message_type : Int,
  subtype : Bytes,
  data : Bytes,
) -> Int = "moonbit_wm_ipc_send"

///|
/// Send an IPC request and wait for the raw response bytes.
#borrow(subtype, data)
pub extern "C" fn wm_ipc_request_bytes(
  source_window_id : Int,
  target_window_id : Int,
  subtype : Bytes,
  data : Bytes,
  timeout_ms : Int,
) -> Bytes = "moonbit_wm_ipc_request_bytes"

///|
/// Send an IPC response that matches a previous request id.
#borrow(data)
pub extern "C" fn wm_ipc_respond(
  source_window_id : Int,
  target_window_id : Int,
  request_id : Int,
  data : Bytes,
) -> Int = "moonbit_wm_ipc_respond"

// `wm_ipc_pop_message_wire` is co-located with its C implementation in
// `ffi/window_manager/binding.mbt`; call it as
// `@window_manager.wm_ipc_pop_message_wire`.
