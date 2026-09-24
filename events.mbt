// Cross-window event push.
//
// The bus lives in the **main process** and maps each window label to its
// globally-unique window id. When one window emits a message targeted at
// another label, the main-process router sends a directed IPC event to that
// window; the target child process receives it on its IPC listener thread and
// evals a `CustomEvent("lepus_event")` into that window's JavaScript.
//
// Frontend:
//   window.addEventListener("lepus_event", e => {
//     const { event, payload } = e.detail; // event: string, payload: object
//   });
// Or emit from any window: `window.lepusApi.events.emit({ target, event, payload })`.

///|
pub struct EmitRequest {
  target : String
  event : String
  payload : Json
} derive(ToJson, FromJson)

///|
pub extend EmitRequest with ToJson::{to_json}

///|
pub extend EmitRequest with @json.FromJson::{from_json}

///|
pub struct EventBus {
  window_ids : Map[String, Int]
}

///|
pub fn EventBus::new(window_ids : Map[String, Int]) -> EventBus {
  { window_ids, }
}

///|
/// Returns the window id for a label, or `-1` if unknown.
pub fn EventBus::window_id(self : EventBus, label : String) -> Int {
  match self.window_ids.get(label) {
    Some(id) => id
    None => -1
  }
}

///|
/// Constructs the JS snippet that dispatches `CustomEvent("lepus_event")` with
/// `detail = { event: <name>, payload: <json> }` into the target window.
fn event_eval_js(event : String, payload : Json) -> String {
  let event_literal = Json::string(event).stringify()
  let payload_json = payload.stringify()
  "window.dispatchEvent(new CustomEvent(\"lepus_event\",{detail:" +
  "{\"event\":" +
  event_literal +
  ",\"payload\":" +
  payload_json +
  "}}));"
}

///|
/// Builds the `events` plugin. Its `emit` command resolves the target label
/// into a window id and sends a directed IPC event carrying the JS snippet.
///
/// `wm` must be the main-process `WindowManager` (the plugin is installed on
/// the main-process router, whose handler performs the directed send).
pub fn EventBus::plugin(
  self : EventBus,
  wm : @webview.WindowManager,
) -> @webview.Plugin {
  @webview.Plugin("events", plugin => {
    plugin.command_sync("emit", fn(request : EmitRequest) -> Bool {
      let id = self.window_id(request.target)
      guard id > 0 else { false }
      let js = event_eval_js(request.event, request.payload)
      wm.send_message(0, id, @webview.IpcMessageType::Event, "lepus-event", js) ==
      0
    })
  })
}

///|
test "event eval snippet embeds event and payload as a JS object literal" {
  let js = event_eval_js("greet", Json::string("hi"))
  assert_eq(
    js, "window.dispatchEvent(new CustomEvent(\"lepus_event\",{detail:{\"event\":\"greet\",\"payload\":\"hi\"}}));",
  )
}

///|
test "event bus resolves window ids by label" {
  let ids = Map([])
  ids.set("main", 1)
  ids.set("settings", 2)
  let bus = EventBus::new(ids)
  assert_eq(bus.window_id("main"), 1)
  assert_eq(bus.window_id("settings"), 2)
  assert_eq(bus.window_id("unknown"), -1)
}

// ════════════════════════════════════════════════════════════════
// 单进程模式：本地事件总线（直接 eval，无 IPC）
// ════════════════════════════════════════════════════════════════
// 单进程多窗口模式下，所有窗口在同一进程，事件可直接 `webview.eval`
// 投递到目标窗口，无需 IPC。这同时让整个应用共享一个 NSApplication /
// Dock 图标（macOS），窗口天然可聚焦。

///|
/// 本地事件总线：label → WebView 句柄的直接映射。
pub struct LocalEventBus {
  webviews : Map[String, @webview.WebView[Unit]]
}

///|
pub fn LocalEventBus::new() -> LocalEventBus {
  { webviews: Map([]), }
}

///|
pub fn LocalEventBus::register(
  self : LocalEventBus,
  label : String,
  webview : @webview.WebView[Unit],
) -> Unit {
  self.webviews.set(label, webview)
}

///|
/// 构建 `events` 插件。`emit` 直接对目标窗口的 WebView 执行 eval，
/// 触发 `CustomEvent("lepus_event")`。同进程内即时送达，无 IPC 开销。
pub fn LocalEventBus::plugin(self : LocalEventBus) -> @webview.Plugin {
  @webview.Plugin("events", plugin => {
    plugin.command_sync("emit", fn(request : EmitRequest) -> Bool {
      match self.webviews.get(request.target) {
        Some(wv) => {
          wv.eval(event_eval_js(request.event, request.payload))
          true
        }
        None => false
      }
    })
  })
}
