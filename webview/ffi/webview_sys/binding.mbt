/// Raw `webview` C-library bindings, isolated from the window-manager runtime
/// in its own small FFI package.
///
/// This is the bottom of the FFI stack: nothing here touches `g_wm` or window
/// ids. It bridges MoonBit closures to the `webview.h` C API and vice versa.
///
/// See `binding.mbt` (in `lepus-apps/lepus/webview`) for the window-manager
/// (`wm_*`) bindings, which build on top of these types.

///|
/// Opaque handle returned by webview_create. C manages the underlying object.
#external
pub type WebView_t

///|
/// Opaque binding record returned by moonbit_webview_bind.
/// C allocates and owns it; MoonBit holds it only as a cookie for unbind.
#external
pub type BindingHandle

// ── Bindings ─────────────────────────────────────────────────────────────────

///|
/// Bind a MoonBit closure as a named JavaScript function.
/// `name` is borrowed (used only during the call).
/// `closure` ownership transfers to the returned BindingHandle.
#borrow(name)
#owned(closure)
pub extern "C" fn webview_bind(
  w : WebView_t,
  name : Bytes,
  call_closure : FuncRef[(Bytes, Bytes, (Bytes, Bytes) -> Unit) -> Unit],
  closure : (Bytes, Bytes) -> Unit,
) -> BindingHandle = "moonbit_webview_bind"

// ── Helpers ──────────────────────────────────────────────────────────────────

///|
/// Copy a raw C string (seq/req pointer) into MoonBit Bytes.
#borrow(cstr)
pub extern "C" fn webview_copy_cstr(cstr : Bytes) -> Bytes = "moonbit_webview_copy_cstr"

///|
/// Register a custom scheme backed by a local root directory.
#borrow(w, scheme, root_dir)
pub extern "C" fn webview_set_custom_protocol(
  w : WebView_t,
  scheme : Bytes,
  root_dir : Bytes,
) -> Int = "webview_set_custom_protocol"

///|
/// Run a MoonBit closure on a detached native thread.
#owned(closure)
pub extern "C" fn run_in_background_thread(
  call_closure : FuncRef[(() -> Unit) -> Unit],
  closure : () -> Unit,
) -> Int = "moonbit_run_in_background_thread"

///|
/// Send a raw string return for a pending webview request.
#borrow(w, seq, result)
pub extern "C" fn webview_return_raw(
  w : WebView_t,
  seq : Bytes,
  status : Int,
  result : Bytes,
) -> Unit = "moonbit_webview_return_raw"

///|
/// Terminate a raw webview event loop.
pub extern "C" fn webview_terminate(w : WebView_t) -> Unit = "moonbit_webview_terminate"
