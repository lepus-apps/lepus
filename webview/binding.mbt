/// FFI declarations for the window-manager C runtime (`wm_*` bindings).
///
/// The raw `webview.h` bindings (handle type, bind/unbind, background thread,
/// string copy, return and terminate) live in the smaller
/// `lepus-apps/lepus/webview/ffi/webview_sys` package, imported here as
/// `@webview_sys`.
///
/// Ownership rules (moonbit-c-binding skill):
///   #borrow(param) — C only reads the value during the call, does not store it.
///   #owned(param)  — ownership transfers to C; C must moonbit_decref when done.
/// Primitives (Int, Int64, Bool, …) are passed by value — no annotation needed.
///
/// see: https://github.com/webview/webview/blob/master/webview.h

///|
/// Set managed window size.
pub extern "C" fn wm_set_size(
  window_id : Int,
  width : Int,
  height : Int,
  hints : SizeHint,
) -> Int = "moonbit_wm_set_size"

///|
/// Apply native custom-window style flags.
pub extern "C" fn wm_set_window_customization(
  window_id : Int,
  frameless : Int,
  resizable : Int,
  closeable : Int,
  always_on_top : Int,
  transparent : Int,
  title_bar_style : TitleBarStyle,
  title_bar_overlay : Int,
) -> Int = "moonbit_wm_set_window_customization"
