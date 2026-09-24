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
