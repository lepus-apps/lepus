// Cross-window event bus.
//
// The event bus lives in the **main process** and is the foundation for
// cross-window communication. Each window labels itself; a window can "emit"
// a message targeted at another label, and the target can "poll" (drain) the
// messages queued for it.
//
// Implementation deliberately routes everything through the existing
// command bridge (JS → MoonBit request, forwarded by the child-side proxy to
// the main-process router). This keeps cross-window events reliable without
// adding a MoonBit→JS push channel or a child-side background listener loop.

///|
pub struct EventMessage {
  event : String
  payload : Json
} derive(Eq, ToJson, FromJson)

///|
pub struct EmitRequest {
  target : String
  event : String
  payload : Json
} derive(ToJson, FromJson)

///|
pub struct PollRequest {
  label : String
} derive(ToJson, FromJson)

///|
pub extend EventMessage with Eq::{not_equal, equal}

///|
pub extend EventMessage with ToJson::{to_json}

///|
pub extend EventMessage with @json.FromJson::{from_json}

///|
pub extend EmitRequest with ToJson::{to_json}

///|
pub extend EmitRequest with @json.FromJson::{from_json}

///|
pub extend PollRequest with ToJson::{to_json}

///|
pub extend PollRequest with @json.FromJson::{from_json}

///|
pub struct EventBus {
  queues : Map[String, Array[EventMessage]]
}

///|
pub fn EventBus::new() -> EventBus {
  { queues: Map([]), }
}

///|
pub fn EventBus::push(
  self : EventBus,
  label : String,
  event : String,
  payload : Json,
) -> Unit {
  let existing = match self.queues.get(label) {
    Some(items) => items
    None => []
  }
  self.queues.set(label, existing + [{ event, payload, }])
}

///|
/// Drains and clears all queued messages for `label`.
pub fn EventBus::drain(self : EventBus, label : String) -> Array[EventMessage] {
  let items = match self.queues.get(label) {
    Some(items) => items
    None => []
  }
  self.queues.set(label, [])
  items
}

///|
/// Builds the `events` plugin. Installed at the App level so that both the
/// main-process router (`emit`/`poll` real handlers) and each child proxy
/// expose `window.lepusApi.events`:
///
/// - `emit({ target, event, payload })` → queues a message for another window
/// - `poll({ label })` → drains this window's queue
///
/// The plugin callbacks capture `self`, whose shared `Map` is mutated across
/// requests so messages persist between polls.
pub fn EventBus::plugin(self : EventBus) -> @webview.Plugin {
  @webview.Plugin("events", plugin => {
    plugin.command_sync("emit", fn(request : EmitRequest) -> Bool {
      self.push(request.target, request.event, request.payload)
      true
    })
    plugin.command_sync("poll", fn(
      request : PollRequest,
    ) -> Array[EventMessage] {
      self.drain(request.label)
    })
  })
}

///|
test "event bus drains messages for a specific label" {
  let bus = EventBus::new()
  bus.push("receiver", "greet", Json::string("h"))
  bus.push("receiver", "ping", Json::number(1))
  bus.push("other", "ignored", Json::string("x"))
  let drained = bus.drain("receiver")
  assert_eq(drained.length(), 2)
  assert_eq(drained[0].event, "greet")
  assert_eq(drained[1].event, "ping")
  // drain clears the queue
  assert_eq(bus.drain("receiver").length(), 0)
}

///|
test "event bus isolates labels" {
  let bus = EventBus::new()
  bus.push("a", "to-a", Json::number(1))
  bus.push("b", "to-b", Json::number(2))
  let for_a = bus.drain("a")
  assert_eq(for_a.length(), 1)
  assert_eq(for_a[0].event, "to-a")
  // b still has its own message
  let for_b = bus.drain("b")
  assert_eq(for_b.length(), 1)
  assert_eq(for_b[0].event, "to-b")
}
