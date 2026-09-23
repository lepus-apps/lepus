///|
/// IPC command request exchanged between the child webview process and the
/// parent async dispatcher.
pub struct ProcessCommandRequest {
  name : String
  payload : Json
} derive(ToJson, FromJson)

///|
/// IPC command response returned by the parent async dispatcher.
pub(all) enum ProcessCommandResponse {
  Ok(Json)
  Error(String)
} derive(ToJson, FromJson)

///|
suberror ProcessCommandError {
  ProcessCommandError(String)
}

///|
pub fn[Payload : ToJson] ProcessCommandRequest::new(
  name : String,
  payload : Payload,
) -> ProcessCommandRequest {
  { name, payload: payload.to_json() }
}

///|
pub fn ProcessCommandRequest::parse(
  raw : String,
) -> ProcessCommandRequest raise ProcessCommandError {
  let json = @json.parse(raw) catch {
    _ => raise ProcessCommandError("Bad bridge request JSON")
  }
  @json.from_json(json) catch {
    _ => raise ProcessCommandError("Bad bridge request shape")
  }
}

///|
pub fn[Payload : ToJson] ProcessCommandResponse::ok(
  payload : Payload,
) -> ProcessCommandResponse {
  Ok(payload.to_json())
}

///|
pub fn ProcessCommandResponse::error(
  message : String,
) -> ProcessCommandResponse {
  Error(message)
}

///|
pub fn ProcessCommandResponse::stringify(
  self : ProcessCommandResponse,
) -> String {
  (
    match self {
      Ok(payload) => [1, payload]
      Error(message) => [0, message]
    } : Json).stringify()
}

///|
pub fn[Reply : @json.FromJson] ProcessCommandResponse::decode_reply(
  self : ProcessCommandResponse,
) -> Reply raise ProcessCommandError {
  match self {
    Ok(reply_json) =>
      @json.from_json(reply_json) catch {
        _ => raise ProcessCommandError("Bad bridge reply payload")
      }
    Error(message) => raise ProcessCommandError(message)
  }
}

///|
pub fn[Reply : @json.FromJson] decode_process_command_response(
  raw : String,
) -> Reply raise ProcessCommandError {
  guard raw != "" else { raise ProcessCommandError("IPC request failed") }
  let json = @json.parse(raw) catch {
    _ => raise ProcessCommandError("Bad bridge response JSON")
  }
  let response = decode_process_command_response_wire(json) catch {
    _ => raise ProcessCommandError("Bad bridge response shape")
  }
  response.decode_reply()
}

///|
fn decode_process_command_response_wire(
  json : Json,
) -> ProcessCommandResponse raise ProcessCommandError {
  match json {
    [1, payload] => Ok(payload)
    [0, String(message)] => Error(message)
    _ => raise ProcessCommandError("Bad bridge response shape")
  }
}

///|
pub struct ProcessCommandProxy {
  wm : WindowManager
  source_window_id : Int
  subtype : String
}

///|
/// Parent-process command router for requests coming from a child webview
/// process.
pub struct ProcessCommandRouter {
  handlers : Map[String, async (Json) -> ProcessCommandResponse]
}

///|
/// Plugin-scoped registration context for `ProcessCommandRouter`.
pub struct ProcessPluginRouter {
  router : ProcessCommandRouter
  plugin_name : String
}

///|
fn[Payload : @json.FromJson] decode_process_command_payload(
  payload_json : Json,
) -> Payload raise ProcessCommandError {
  @json.from_json(payload_json) catch {
    _ => raise ProcessCommandError("Bad command payload")
  }
}

///|
fn[Payload : @json.FromJson] register_process_command(
  router : ProcessCommandRouter,
  name : String,
  callback : async (Payload) -> ProcessCommandResponse,
) -> Unit {
  router.handlers.set(name, payload_json => {
    let payload : Payload = decode_process_command_payload(payload_json) catch {
      ProcessCommandError(message) =>
        return ProcessCommandResponse::error(message)
    }
    callback(payload)
  })
}

///|
pub fn ProcessCommandProxy::new(
  wm : WindowManager,
  source_window_id : Int,
  subtype? : String = "bridge_command",
) -> ProcessCommandProxy {
  { wm, source_window_id, subtype }
}

///|
/// Creates a parent-process command router.
pub fn ProcessCommandRouter::new() -> ProcessCommandRouter {
  { handlers: {} }
}

///|
/// Registers a plugin namespace on the parent-process router.
pub fn ProcessCommandRouter::plugin(
  self : ProcessCommandRouter,
  plugin_name : String,
  register : (ProcessPluginRouter) -> Unit,
) -> Unit {
  register({ router: self, plugin_name })
}

///|
pub fn[Payload : ToJson, Reply : @json.FromJson] ProcessCommandProxy::call(
  self : ProcessCommandProxy,
  name : String,
  payload : Payload,
  target_window_id? : Int = 0,
  timeout_ms? : Int = 10_000,
) -> Reply raise ProcessCommandError {
  let request = ProcessCommandRequest::new(name, payload)
  let raw = self.wm.request(
    self.source_window_id,
    target_window_id,
    self.subtype,
    request.to_json().stringify(),
    timeout_ms~,
  )
  decode_process_command_response(raw)
}

///|
pub fn[Payload : ToJson, Reply : @json.FromJson] ProcessCommandProxy::call_plugin(
  self : ProcessCommandProxy,
  plugin_name : String,
  api_name : String,
  payload : Payload,
  target_window_id? : Int = 0,
  timeout_ms? : Int = 10_000,
) -> Reply raise ProcessCommandError {
  self.call(
    make_process_plugin_command_name(plugin_name, api_name),
    payload,
    target_window_id~,
    timeout_ms~,
  )
}

///|
/// Builds a typed forwarding closure for a plugin command handled by the
/// parent process.
pub fn[Payload : ToJson, Reply : @json.FromJson] ProcessCommandProxy::plugin_handler(
  self : ProcessCommandProxy,
  plugin_name : String,
  api_name : String,
  target_window_id? : Int = 0,
  timeout_ms? : Int = 10_000,
) -> (Payload) -> Reply raise {
  fn(payload : Payload) -> Reply raise {
    self.call_plugin(
      plugin_name,
      api_name,
      payload,
      target_window_id~,
      timeout_ms~,
    )
  }
}

///|
/// Dispatches a parsed process command through the registered router handlers.
pub async fn ProcessCommandRouter::dispatch(
  self : ProcessCommandRouter,
  request : ProcessCommandRequest,
) -> ProcessCommandResponse {
  match self.handlers.get(request.name) {
    Some(handler) => handler(request.payload)
    None => ProcessCommandResponse::error("Unknown command: " + request.name)
  }
}

///|
/// Serves process commands from a child webview by using the registered router.
pub async fn ProcessCommandRouter::serve(
  self : ProcessCommandRouter,
  wm : WindowManager,
  child_pid : Int,
  subtype? : String = "bridge_command",
) -> Unit {
  wm.serve_process_commands(
    child_pid,
    request => self.dispatch(request),
    subtype~,
  )
}

///|
/// Registers a typed synchronous command on the parent-process router.
pub fn[Payload : @json.FromJson, Reply : ToJson] ProcessCommandRouter::handle(
  self : ProcessCommandRouter,
  name : String,
  callback : (Payload) -> Reply,
) -> Unit {
  register_process_command(self, name, payload => {
    ProcessCommandResponse::ok(callback(payload))
  })
}

///|
/// Registers a typed synchronous command that can return explicit errors.
pub fn[Payload : @json.FromJson, Reply : ToJson] ProcessCommandRouter::handle_result(
  self : ProcessCommandRouter,
  name : String,
  callback : (Payload) -> Reply raise Error,
) -> Unit {
  register_process_command(self, name, payload => {
    let reply = callback(payload) catch {
      message => return ProcessCommandResponse::error(message.to_string())
    }
    ProcessCommandResponse::ok(reply)
  })
}

///|
/// Registers a typed async command on the parent-process router.
pub fn[Payload : @json.FromJson, Reply : ToJson] ProcessCommandRouter::handle_async(
  self : ProcessCommandRouter,
  name : String,
  callback : async (Payload) -> Reply,
) -> Unit {
  register_process_command(self, name, payload => {
    let reply = callback(payload)
    ProcessCommandResponse::ok(reply)
  })
}

///|
/// Registers a typed async command that can return explicit errors.
pub fn[Payload : @json.FromJson, Reply : ToJson] ProcessCommandRouter::handle_result_async(
  self : ProcessCommandRouter,
  name : String,
  callback : async (Payload) -> Reply raise Error,
) -> Unit {
  register_process_command(self, name, payload => {
    let reply = callback(payload) catch {
      message => return ProcessCommandResponse::error(message.to_string())
    }
    ProcessCommandResponse::ok(reply)
  })
}

///|
/// Registers a typed synchronous plugin command on the parent-process router.
pub fn[Payload : @json.FromJson, Reply : ToJson] ProcessPluginRouter::command(
  self : ProcessPluginRouter,
  api_name : String,
  callback : (Payload) -> Reply,
) -> Unit {
  self.router.handle(
    make_process_plugin_command_name(self.plugin_name, api_name),
    callback,
  )
}

///|
/// Registers a typed synchronous plugin command that can return explicit
/// errors.
pub fn[Payload : @json.FromJson, Reply : ToJson] ProcessPluginRouter::command_result(
  self : ProcessPluginRouter,
  api_name : String,
  callback : (Payload) -> Reply raise Error,
) -> Unit {
  self.router.handle_result(
    make_process_plugin_command_name(self.plugin_name, api_name),
    callback,
  )
}

///|
/// Registers a typed async plugin command on the parent-process router.
pub fn[Payload : @json.FromJson, Reply : ToJson] ProcessPluginRouter::command_async(
  self : ProcessPluginRouter,
  api_name : String,
  callback : async (Payload) -> Reply,
) -> Unit {
  self.router.handle_async(
    make_process_plugin_command_name(self.plugin_name, api_name),
    callback,
  )
}

///|
/// Registers a typed async plugin command that can return explicit errors.
pub fn[Payload : @json.FromJson, Reply : ToJson] ProcessPluginRouter::command_result_async(
  self : ProcessPluginRouter,
  api_name : String,
  callback : async (Payload) -> Reply raise Error,
) -> Unit {
  self.router.handle_result_async(
    make_process_plugin_command_name(self.plugin_name, api_name),
    callback,
  )
}

///|
pub async fn WindowManager::serve_process_commands(
  self : WindowManager,
  child_pid : Int,
  handler : async (ProcessCommandRequest) -> ProcessCommandResponse,
  subtype? : String = "bridge_command",
) -> Unit {
  while self.wait_child_noblock(child_pid) == 0 {
    match self.try_pop_message(0) {
      Some(message) =>
        if message.message_type == Request && message.subtype == subtype {
          let response = try {
            let request = ProcessCommandRequest::parse(message.data)
            handler(request)
          } catch {
            ProcessCommandError(message) =>
              ProcessCommandResponse::error(message)
            _ => ProcessCommandResponse::error("Unexpected bridge error")
          }
          ignore(
            self.respond(
              0,
              message.source_window_id,
              message.message_id,
              response.stringify(),
            ),
          )
        } else {
          @async.pause()
        }
      None => @async.sleep(10)
    }
  }
}

///|
fn make_process_plugin_command_name(
  plugin_name : String,
  api_name : String,
) -> String {
  "plugin:\{Json::string(plugin_name).stringify()}:\{Json::string(api_name).stringify()}"
}

///|
test "ProcessCommandResponse ok stringifies without enum tag" {
  let raw = ProcessCommandResponse::ok({ "total": Json::number(5) }).stringify()
  assert_eq(raw, "[1,{\"total\":5}]")
}

///|
test "ProcessCommandResponse error stringifies without enum tag" {
  let raw = ProcessCommandResponse::error("oops").stringify()
  assert_eq(raw, "[0,\"oops\"]")
}

///|
struct ProcessCommandReplyForTest {
  total : Int
} derive(FromJson)

///|
test "decode_process_command_response supports tagged ok payload" {
  let reply : ProcessCommandReplyForTest = decode_process_command_response(
    "[1,{\"total\":5}]",
  ) catch {
    ProcessCommandError(message) => abort(message)
  }
  assert_eq(reply.total, 5)
}
