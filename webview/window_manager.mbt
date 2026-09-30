///|
/// Window state mapped from native window manager.
pub(all) enum WindowState {
  Unknown = 0
  Created = 1
  Running = 2
  Hidden = 3
  Closing = 4
  Closed = 5
} derive(Eq)

///|
pub fn WindowState::int(self : WindowState) -> Int = "%identity"

///|
test {
  inspect(WindowState::Created.int(), content="1")
}

///|
/// Process type returned by native window manager.
pub(all) enum ProcessType {
  Main = 0
  Child = 1
  Unknown = 2
} derive(Eq)

///|
/// IPC message kind.
pub(all) enum IpcMessageType {
  Data = 0
  Command = 1
  Event = 2
  Request = 3
  Response = 4
} derive(Eq)

///|
pub fn IpcMessageType::int(self : IpcMessageType) -> Int = "%identity"

///|
/// macOS title-bar style, mirrors Tauri 2's `titleBarStyle`. On other
/// platforms it selects the closest native title-bar behavior.
pub(all) enum TitleBarStyle {
  /// Visible: normal native title bar (default).
  Visible = 0
  /// Transparent: native title bar rendered transparent, still present.
  Transparent = 1
  /// Overlay: content extends underneath the native title bar (macOS keeps
  /// the traffic-light buttons); the typical starting point for a custom
  /// title bar.
  Overlay = 2
} derive(Debug, Eq)

///|
/// Native window style configuration, aligned with the subset of Tauri 2's
/// `WindowConfig` that maps onto a desktop window's native chrome.
///
/// Every field has a Tauri-compatible default; build one by overriding only
/// what you need. `decorations = false` is the frameless/borderless mode
/// (`frameless` in earlier Lepus versions).
pub struct WindowOptions {
  /// Whether the window keeps the OS-provided chrome (title bar + border).
  /// `false` produces a frameless window.
  decorations : Bool
  /// Whether the user may resize the window.
  resizable : Bool
  /// Whether the window's close button is enabled.
  closeable : Bool
  /// Whether the window's minimize button is enabled.
  minimizable : Bool
  /// Whether the window's maximize/zoom button is enabled.
  maximizable : Bool
  /// Keep the window above all normal windows.
  always_on_top : Bool
  /// Keep the window below all normal windows.
  always_on_bottom : Bool
  /// Window background is transparent (requires page background support).
  transparent : Bool
  /// Draw the system drop shadow.
  shadow : Bool
  /// Hide the window from the taskbar / Dock window list.
  skip_taskbar : Bool
  /// Show the window on every workspace (macOS/Linux).
  visible_on_all_workspaces : Bool
  /// Native title-bar style (macOS `titleBarStyle`).
  title_bar_style : TitleBarStyle
  /// Let window content extend under the title bar (custom title bars).
  title_bar_overlay : Bool
  /// Hide only the title text while keeping the title bar.
  hidden_title : Bool
}

///|
/// Tauri-compatible defaults for [`WindowOptions`].
pub fn WindowOptions::default() -> WindowOptions {
  {
    decorations: true,
    resizable: true,
    closeable: true,
    minimizable: true,
    maximizable: true,
    always_on_top: false,
    always_on_bottom: false,
    transparent: false,
    shadow: true,
    skip_taskbar: false,
    visible_on_all_workspaces: false,
    title_bar_style: Visible,
    title_bar_overlay: false,
    hidden_title: false,
  }
}

///|
test "WindowOptions::default matches Tauri window defaults" {
  let options = WindowOptions::default()
  assert_true(options.decorations)
  assert_true(options.resizable)
  assert_true(options.closeable)
  assert_true(options.minimizable)
  assert_true(options.maximizable)
  assert_false(options.always_on_top)
  assert_false(options.always_on_bottom)
  assert_false(options.transparent)
  assert_true(options.shadow)
  assert_false(options.skip_taskbar)
  assert_false(options.visible_on_all_workspaces)
  assert_eq(options.title_bar_style, TitleBarStyle::Visible)
  assert_false(options.title_bar_overlay)
  assert_false(options.hidden_title)
}

///|
test "wm_flag encodes booleans as the native 1/0 layout" {
  assert_eq(wm_flag(true), 1)
  assert_eq(wm_flag(false), 0)
}

///|
/// Thin high-level wrapper over native window manager (stub.c wm_* APIs).
pub struct WindowManager {
  process_type : ProcessType
  mut window_ids : Array[Int]
}

///|
/// Snapshot of one IPC message copied out of the native queue.
pub struct IpcMessage {
  source_window_id : Int
  target_window_id : Int
  message_type : IpcMessageType
  message_id : Int
  subtype : String
  data : String
}

///|
fn i32_le_at(wire : Bytes, offset : Int) -> Int? {
  guard offset >= 0 && offset + 3 < wire.length() else { None }
  let b0 = wire[offset].to_int()
  let b1 = wire[offset + 1].to_int()
  let b2 = wire[offset + 2].to_int()
  let b3 = wire[offset + 3].to_int()
  Some(b0 + (b1 << 8) + (b2 << 16) + (b3 << 24))
}

///|
fn ipc_message_type_from_int(value : Int) -> IpcMessageType {
  match value {
    0 => IpcMessageType::Data
    1 => Command
    2 => Event
    3 => Request
    4 => Response
    _ => Data
  }
}

///|
fn decode_ipc_message_wire(wire : Bytes) -> IpcMessage? {
  guard wire.length() >= 24 else { None }
  let source_window_id = i32_le_at(wire, 0).unwrap()
  let target_window_id = i32_le_at(wire, 4).unwrap()
  let message_type = ipc_message_type_from_int(i32_le_at(wire, 8).unwrap())
  let message_id = i32_le_at(wire, 12).unwrap()
  let subtype_len = i32_le_at(wire, 16).unwrap()
  let data_len = i32_le_at(wire, 20).unwrap()
  guard subtype_len >= 0 && data_len >= 0 else { None }
  let subtype_start = 24
  let data_start = subtype_start + subtype_len
  guard data_start + data_len <= wire.length() else { None }
  let subtype = @encoding/utf8.decode(
    wire.exact_view(start=subtype_start, end=data_start),
  ) catch {
    _ => ""
  }
  let data = @encoding/utf8.decode(
    wire.exact_view(start=data_start, end=data_start + data_len),
  ) catch {
    _ => ""
  }
  Some({
    source_window_id,
    target_window_id,
    message_type,
    message_id,
    subtype,
    data,
  })
}

///|
fn i32_le_bytes(value : Int) -> Bytes {
  Bytes::makei(4, i => {
    match i {
      0 => (value & 0xFF).to_byte()
      1 => ((value >> 8) & 0xFF).to_byte()
      2 => ((value >> 16) & 0xFF).to_byte()
      _ => ((value >> 24) & 0xFF).to_byte()
    }
  })
}

///|
test "decode_ipc_message_wire" {
  let subtype = @encoding/utf8.encode("ready")
  let data = @encoding/utf8.encode("{\"ok\":true}")
  let wire = i32_le_bytes(7) +
    i32_le_bytes(9) +
    i32_le_bytes(IpcMessageType::Request.int()) +
    i32_le_bytes(42) +
    i32_le_bytes(subtype.length()) +
    i32_le_bytes(data.length()) +
    subtype +
    data
  let message = decode_ipc_message_wire(wire).unwrap()
  inspect(message.source_window_id, content="7")
  inspect(message.target_window_id, content="9")
  inspect(message.message_type == Request, content="true")
  inspect(message.message_id, content="42")
  inspect(message.subtype, content="ready")
  inspect(message.data, content="{\"ok\":true}")
  inspect(decode_ipc_message_wire(b"") is None, content="true")
  inspect(decode_ipc_message_wire(b"\x01\x02") is None, content="true")
}

///|
/// Initialize WM runtime for current process.
///
/// - main process: pass `true`
/// - child process: pass `false`
pub fn WindowManager::init(is_main? : Bool = true) -> WindowManager {
  let ok = @window_manager.wm_init(if is_main { 1 } else { 0 })
  guard ok == 0 else { abort("WindowManager::init failed") }
  let process_type = match @window_manager.wm_get_process_type() {
    0 => ProcessType::Main
    1 => Child
    _ => Unknown
  }
  { process_type, window_ids: [], }
}

///|
/// Install the standard application main menu (macOS) so keyboard shortcuts
/// work: Cmd+Q (quit app), Cmd+W (close window), Cmd+M (minimize), and the
/// Edit menu (Cmd+Z/X/C/V/A). No-op on other platforms.
pub fn WindowManager::install_default_app_menu(_self : WindowManager) -> Int {
  @window_manager.wm_install_default_app_menu()
}

///|
/// Set the NSApplication activation policy (macOS). No-op on other platforms.
pub fn WindowManager::set_activation_policy(
  _self : WindowManager,
  policy : Int,
) -> Int {
  @window_manager.wm_set_activation_policy(policy)
}

///|
/// Cleanup native WM runtime.
pub fn WindowManager::destroy(self : WindowManager) -> Unit {
  @window_manager.wm_cleanup()
  self.window_ids = []
}

///|
/// Create a native window in current process.
pub fn WindowManager::create_window(
  self : WindowManager,
  title : String,
  url : String,
  width? : Int = 800,
  height? : Int = 600,
) -> Int {
  let id = @window_manager.wm_create_window(
    @encoding/utf8.encode(title),
    @encoding/utf8.encode(url),
    width,
    height,
    -1,
    -1,
    0,
    0,
    -1,
  )
  guard id > 0 else { abort("WindowManager::create_window failed") }
  self.window_ids.push(id)
  id
}

///|
/// Spawn a child process window. Returns child process pid.
pub fn WindowManager::create_child_window(
  _self : WindowManager,
  title : String,
  url : String,
  width? : Int = 800,
  height? : Int = 600,
  parent_id? : Int = -1,
) -> Int {
  @window_manager.wm_create_child_window(
    @encoding/utf8.encode(title),
    @encoding/utf8.encode(url),
    width,
    height,
    parent_id,
  )
}

///|
/// Fork the current process. The parent receives the child pid, the child receives `0`.
pub fn WindowManager::fork_process(_self : WindowManager) -> Int {
  @window_manager.wm_fork_process()
}

///|
/// Spawn a fresh child process by exec-ing the given program path with one extra argument.
pub fn WindowManager::spawn_process(
  _self : WindowManager,
  program : String,
  arg1 : String,
) -> Int {
  @window_manager.wm_spawn_process(
    @encoding/utf8.encode(program),
    @encoding/utf8.encode(arg1),
  )
}

///|
/// Connect current process to the main-process IPC server and switch into child mode.
pub fn WindowManager::connect_child_process() -> Int {
  @window_manager.wm_connect_child_process()
}

///|
/// Set the current (child) process window-id starting base.
///
/// The main process assigns each child a globally unique base so that windows
/// created in different children never collide on `window_id` (used for IPC
/// routing). Call before creating any window in the child process.
pub fn WindowManager::set_window_id_base(
  _self : WindowManager,
  base : Int,
) -> Int {
  @window_manager.wm_set_window_id_base(base)
}

///|
/// Return true when running in main process.
pub fn WindowManager::is_main_process(self : WindowManager) -> Bool {
  self.process_type == Main
}

///|
/// Return true when running in child process.
pub fn WindowManager::is_child_process(self : WindowManager) -> Bool {
  self.process_type == Child
}

///|
/// Run a window event loop.
pub fn WindowManager::run_window(_self : WindowManager, window_id : Int) -> Int {
  @window_manager.wm_run_window(window_id)
}

///|
/// Destroy a window.
pub fn WindowManager::destroy_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_destroy_window(window_id)
}

///|
/// Encode a boolean flag as the `1`/`0` int the native layer expects.
fn wm_flag(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}

///|
/// Flatten `options` into the positional FFI call.
fn wm_apply_window_options(window_id : Int, options : WindowOptions) -> Int {
  wm_set_window_customization(
    window_id,
    wm_flag(options.decorations),
    wm_flag(options.resizable),
    wm_flag(options.closeable),
    wm_flag(options.minimizable),
    wm_flag(options.maximizable),
    wm_flag(options.always_on_top),
    wm_flag(options.always_on_bottom),
    wm_flag(options.transparent),
    wm_flag(options.shadow),
    wm_flag(options.skip_taskbar),
    wm_flag(options.visible_on_all_workspaces),
    options.title_bar_style,
    wm_flag(options.title_bar_overlay),
    wm_flag(options.hidden_title),
  )
}

///|
/// Apply the native window style described by `options`.
pub fn WindowManager::set_window_customization(
  _self : WindowManager,
  window_id : Int,
  options : WindowOptions,
) -> Int {
  wm_apply_window_options(window_id, options)
}

///|
/// Set macOS traffic-light buttons position.
pub fn WindowManager::set_traffic_light_position(
  _self : WindowManager,
  window_id : Int,
  x : Int,
  y : Int,
) -> Int {
  @window_manager.wm_set_traffic_light_position(window_id, x, y)
}

///|
/// Move native window to an absolute screen position.
pub fn WindowManager::set_position(
  _self : WindowManager,
  window_id : Int,
  x : Int,
  y : Int,
) -> Int {
  @window_manager.wm_set_position(window_id, x, y)
}

///|
/// Resize native window.
pub fn WindowManager::set_size(
  _self : WindowManager,
  window_id : Int,
  width : Int,
  height : Int,
  hints : SizeHint,
) -> Int {
  wm_set_size(window_id, width, height, hints)
}

///|
/// Minimize native window.
pub fn WindowManager::minimize_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_minimize_window(window_id)
}

///|
/// Maximize native window.
pub fn WindowManager::maximize_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_maximize_window(window_id)
}

///|
/// Restore native window from maximized state.
pub fn WindowManager::unmaximize_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_unmaximize_window(window_id)
}

///|
/// Toggle native maximize state.
pub fn WindowManager::toggle_maximize_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_toggle_maximize_window(window_id)
}

///|
/// Set native fullscreen state.
pub fn WindowManager::set_fullscreen_window(
  _self : WindowManager,
  window_id : Int,
  fullscreen : Bool,
) -> Int {
  @window_manager.wm_set_fullscreen_window(
    window_id,
    if fullscreen {
      1
    } else {
      0
    },
  )
}

///|
/// Toggle native fullscreen state.
pub fn WindowManager::toggle_fullscreen_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_toggle_fullscreen_window(window_id)
}

///|
/// Start native window drag/move gesture.
pub fn WindowManager::start_drag_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_start_drag_window(window_id)
}

///|
/// Show or hide a native window.
pub fn WindowManager::set_visibility(
  _self : WindowManager,
  window_id : Int,
  visible : Bool,
) -> Int {
  @window_manager.wm_set_visibility(window_id, if visible { 1 } else { 0 })
}

///|
/// Close native window.
pub fn WindowManager::close_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_close_window(window_id)
}

///|
/// Bring a window to front and focus it. On macOS this also activates the
/// process as the foreground application (Tauri `Window::set_focus` parity).
pub fn WindowManager::focus_window(
  _self : WindowManager,
  window_id : Int,
) -> Int {
  @window_manager.wm_focus_window(window_id)
}

///|
/// Enable or disable developer tools integration.
pub fn WindowManager::set_devtools(
  _self : WindowManager,
  window_id : Int,
  enabled : Bool,
) -> Int {
  @window_manager.wm_set_devtools(window_id, if enabled { 1 } else { 0 })
}

///|
/// Send an IPC message.
pub fn WindowManager::send_message(
  _self : WindowManager,
  source_window_id : Int,
  target_window_id : Int,
  message_type : IpcMessageType,
  subtype : String,
  data : String,
) -> Int {
  @window_manager.wm_ipc_send(
    source_window_id,
    target_window_id,
    message_type.int(),
    @encoding/utf8.encode(subtype),
    @encoding/utf8.encode(data),
  )
}

///|
/// Broadcast an event message.
pub fn WindowManager::broadcast(
  self : WindowManager,
  source_window_id : Int,
  subtype : String,
  data : String,
) -> Int {
  self.send_message(source_window_id, 0, Event, subtype, data)
}

///|
/// Send an IPC request and wait for the response body.
pub fn WindowManager::request(
  _self : WindowManager,
  source_window_id : Int,
  target_window_id : Int,
  subtype : String,
  data : String,
  timeout_ms? : Int = 0,
) -> String {
  @encoding/utf8.decode(
    @window_manager.wm_ipc_request_bytes(
      source_window_id,
      target_window_id,
      @encoding/utf8.encode(subtype),
      @encoding/utf8.encode(data),
      timeout_ms,
    ),
  ) catch {
    _ => ""
  }
}

///|
/// Send an IPC response for a previously received request.
pub fn WindowManager::respond(
  _self : WindowManager,
  source_window_id : Int,
  target_window_id : Int,
  request_id : Int,
  data : String,
) -> Int {
  @window_manager.wm_ipc_respond(
    source_window_id,
    target_window_id,
    request_id,
    @encoding/utf8.encode(data),
  )
}

///|
/// Try to pop one queued IPC message for the given queue id.
pub fn WindowManager::try_pop_message(
  _self : WindowManager,
  queue_id : Int,
) -> IpcMessage? {
  decode_ipc_message_wire(@window_manager.wm_ipc_pop_message_wire(queue_id))
}

///|
/// Non-blocking child process status check.
pub fn WindowManager::wait_child_noblock(
  _self : WindowManager,
  pid : Int,
) -> Int {
  @window_manager.wm_wait_child_noblock(pid)
}
