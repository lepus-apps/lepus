// ── Wire protocol ────────────────────────────────────────────────────────────
//
// Command bridge using webview_bind for JS→MoonBit calls (non-blocking).
//
// JS → MoonBit:
//   window.__moonbit_command(name, payload) → webview_bind callback → async task
//
// MoonBit → JS:
//   webview.eval(__dispatch([name, payload])) → CustomEvent listener
//
// The bind callback spawns async tasks immediately, so webview_run never blocks.

///|
/// Structured response returned from JS → MoonBit commands.
pub(all) enum CommandResponse {
  Ok(Json)
  Error(String)
} derive(Eq)

///|
fn[Payload : ToJson] CommandResponse::ok(payload : Payload) -> CommandResponse {
  Ok(payload.to_json())
}

///|
fn CommandResponse::error(message : String) -> CommandResponse {
  Error(message)
}

///|
fn CommandResponse::to_wire(self : CommandResponse) -> Bytes {
  match self {
    Ok(payload) => @encoding/utf8.encode(payload.to_json().stringify())
    Error(msg) => @encoding/utf8.encode("\{msg}")
  }
}

// ── CommandBridge ─────────────────────────────────────────────────────────────

///|
/// High-level command bridge using webview_bind.
///
/// JS API:
/// - `window[global_name].send(name, payload)` → calls MoonBit command
struct CommandBridge[X] {
  webview : WebView[X]
  binding_name : String
  handlers : Map[String, (Json, String, CommandBridge[X]) -> Unit]
}

///|
/// Creates and starts a command bridge for the given webview.
fn[X] CommandBridge::new(
  webview : WebView[X],
  global_name? : String = "lepusBridge",
  binding_name? : String = "__moonbit_command",
) -> CommandBridge[X] {
  let bridge = CommandBridge::{ webview, binding_name, handlers: {} }
  bridge.webview.init(make_bridge_script(global_name, binding_name))
  bridge.start_dispatch()
  bridge
}

///|
fn[X] CommandBridge::destroy(self : CommandBridge[X]) -> Unit {
  self.handlers.clear()
}

// ── Dispatch via webview_bind ───────────────────────────────────────────────

///|
fn[X] CommandBridge::start_dispatch(self : CommandBridge[X]) -> Unit {
  let binding = webview_bind(
    self.webview.handle,
    @encoding/utf8.encode(self.binding_name),
    fn(raw_id, raw_req, f) { f(raw_id, raw_req) },
    fn(raw_id, raw_req) {
      let id = webview_copy_cstr(raw_id)
      let req = webview_copy_cstr(raw_req)
      let id_str = @encoding/utf8.decode(id) catch { Malformed(_) => "" }
      let req_str = @encoding/utf8.decode(req) catch { Malformed(_) => "" }
      log(1, "[bridge:recv] id=\{id_str} req=\{req_str}")
      self.dispatch(id_str, req_str)
    },
  )
  ignore(binding)
}

///|
fn[X] CommandBridge::dispatch(
  self : CommandBridge[X],
  id : String,
  req : String,
) -> Unit {
  let parsed = json_parse(req)
  match parsed {
    [String(name), payload] => {
      log(1, "[bridge:dispatch] name=\{name}")
      match self.handlers.get(name) {
        Some(h) => h(payload, id, self)
        None => {
          let resp = CommandResponse::error("Unknown command: " + name)
          self.send_response(id, resp)
        }
      }
    }
    _ => {
      let resp = CommandResponse::error("Bad request format")
      self.send_response(id, resp)
    }
  }
}

///|
fn json_parse(data : String) -> Json {
  let v = @json.parse(data) catch { _ => Json::null() }
  v
}

///|
fn[X] CommandBridge::send_response(
  self : CommandBridge[X],
  id : String,
  resp : CommandResponse,
) -> Unit {
  log(1, "[bridge:send] id=\{id}")
  let wire = resp.to_wire()
  let status = match resp {
    Ok(_) => 0
    Error(_) => 1
  }
  ignore(
    wm_return_raw(
      self.webview.window_id,
      @encoding/utf8.encode(id),
      status,
      wire,
    ),
  )
}

// ── Handler registration ──────────────────────────────────────────────────────

///|
/// Registers an async typed command handler.
///
/// The callback is an async function. It will be spawned as a background task
/// so it doesn't block the webview event loop.
fn[X, Payload : @json.FromJson, Reply : ToJson] CommandBridge::handle_sync(
  self : CommandBridge[X],
  name : String,
  callback : (Payload) -> Reply,
) -> Unit {
  self.handlers.set(name, fn(json, id, bridge) {
    let payload = @json.from_json(json) catch {
      msg => {
        bridge.send_response(id, CommandResponse::error("\{msg}"))
        return
      }
    }
    bridge.send_response(id, CommandResponse::ok(callback(payload)))
  })
}

///|
/// Registers an async typed command handler.
///
/// The callback is an async function. It will be spawned as a background task
/// so it doesn't block the webview event loop.
fn[X, Payload : @json.FromJson, Reply : ToJson] CommandBridge::handle_async(
  self : CommandBridge[X],
  name : String,
  callback : async (Payload) -> Reply,
) -> Unit {
  self.handlers.set(name, fn(json, id, bridge) {
    let payload = @json.from_json(json) catch {
      msg => {
        bridge.send_response(id, CommandResponse::error("\{msg}"))
        return
      }
    }
    self.webview.task_group.spawn_bg(() => {
      let reply = callback(payload)
      bridge.send_response(id, CommandResponse::ok(reply))
    })
  })
}

///|
/// Registers a typed command handler that runs on a detached native thread.
///
/// This is useful when the callback performs blocking work that should not hold
/// the webview UI thread, while still responding asynchronously to JavaScript.
fn[X, Payload : @json.FromJson, Reply : ToJson] CommandBridge::handle_result_bg(
  self : CommandBridge[X],
  name : String,
  callback : (Payload) -> Reply raise,
) -> Unit {
  self.handlers.set(name, fn(json, id, bridge) {
    let payload = @json.from_json(json) catch {
      msg => {
        bridge.send_response(id, CommandResponse::error("\{msg}"))
        return
      }
    }
    ignore(
      run_in_background_thread(fn(task) { task() }, () => {
        let reply = callback(payload) catch {
          message => {
            bridge.send_response(
              id,
              CommandResponse::error(message.to_string()),
            )
            return
          }
        }
        bridge.send_response(id, CommandResponse::ok(reply))
      }),
    )
  })
}

///|
/// Registers an async typed command handler that can raise errors.
fn[X, Payload : @json.FromJson, Reply : ToJson] CommandBridge::handle_result_async(
  self : CommandBridge[X],
  name : String,
  callback : async (Payload) -> Reply raise Error,
) -> Unit {
  self.handlers.set(name, fn(json, id, bridge) {
    let payload = @json.from_json(json) catch {
      msg => {
        bridge.send_response(id, CommandResponse::error("\{msg}"))
        return
      }
    }
    self.webview.task_group.spawn_bg(() => {
      let reply = callback(payload) catch {
        message => {
          bridge.send_response(id, CommandResponse::error(message.to_string()))
          return
        }
      }
      bridge.send_response(id, CommandResponse::ok(reply))
    })
  })
}

// ── JS scripts ────────────────────────────────────────────────────────────────

///|
fn make_bridge_script(global_name : String, binding_name : String) -> String {
  let g = Json::string(global_name).stringify()
  let b = Json::string(binding_name).stringify()
  //Readable form:
  // window[G] = {
  //   send: (n, p) => window[B](n, p),
  // }
  (
    $|!function(){const G=\{g},B=\{b};window[G]={send:(n,p)=>window[B](n,p??null)};}();
  )
}

// ── Tests ─────────────────────────────────────────────────────────────────────

///|
test "CommandResponse ok encodes as raw JSON payload" {
  let r = CommandResponse::ok({ "x": Json::number(1) })
  let wire = r.to_wire()
  let decoded = @encoding/utf8.decode(wire)
  assert_true(decoded == "{\"x\":1}")
}

///|
test "CommandResponse error encodes as error message string" {
  let r = CommandResponse::error("oops")
  let wire = r.to_wire()
  let decoded = @encoding/utf8.decode(wire)
  assert_true(decoded == "oops")
}
