///|
pub struct ConnectRequest {
  url : String
} derive(ToJson, FromJson)

///|
pub struct ConnectReply {
  ok : Bool
  id : Int?
  error : String?
} derive(ToJson, FromJson)

///|
pub struct SendRequest {
  id : Int
  text : String
} derive(ToJson, FromJson)

///|
pub struct RecvReply {
  ok : Bool
  text : String?
  error : String?
} derive(ToJson, FromJson)

///|
let ws_urls : Ref[Map[Int, String]] = { val: {} }

///|
let ws_last_msg : Ref[Map[Int, String]] = { val: {} }

///|
let next_ws_id : Ref[Int] = { val: 1 }

///|
fn connect(payload : ConnectRequest) -> ConnectReply {
  let id = next_ws_id.val
  next_ws_id.val = next_ws_id.val + 1
  ws_urls.val.set(id, payload.url)
  ws_last_msg.val.set(id, "")
  { ok: true, id: Some(id), error: None }
}

///|
fn send_text(payload : SendRequest) -> Bool {
  match ws_urls.val.get(payload.id) {
    Some(_) => {
      ws_last_msg.val.set(payload.id, payload.text)
      true
    }
    None => false
  }
}

///|
fn recv_text(id : Int) -> RecvReply {
  match ws_urls.val.get(id) {
    Some(_) => {
      let text = ws_last_msg.val.get(id).unwrap_or("")
      { ok: true, text: Some(text), error: None }
    }
    None => { ok: false, text: None, error: Some("connection not found") }
  }
}

///|
fn close_conn(id : Int) -> Bool {
  let existed = ws_urls.val.contains(id)
  ws_urls.val.remove(id)
  ws_last_msg.val.remove(id)
  existed
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("websocket", plugin => {
    plugin.command_sync("connect", (payload : ConnectRequest) => {
      connect(payload)
    })
    plugin.command_sync("send_text", (payload : SendRequest) => {
      send_text(payload)
    })
    plugin.command_sync("recv_text", (payload : Int) => recv_text(payload))
    plugin.command_sync("close", (payload : Int) => close_conn(payload))
  })
}
