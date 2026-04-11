///|
pub struct LoadRequest {
  db : String
} derive(ToJson, FromJson)

///|
pub struct ConnectionReply {
  id : Int
  db : String
} derive(ToJson, FromJson)

///|
pub struct ExecuteRequest {
  conn_id : Int
  sql : String
} derive(ToJson, FromJson)

///|
pub struct ExecuteReply {
  ok : Bool
  error : String?
} derive(ToJson, FromJson)

///|
pub struct SelectReply {
  ok : Bool
  rows : Array[String]
  error : String?
} derive(ToJson, FromJson)

///|
let sql_connections : Ref[Map[Int, String]] = { val: {} }

///|
let next_conn_id : Ref[Int] = { val: 1 }

///|
fn load_connection(payload : LoadRequest) -> ConnectionReply {
  let id = next_conn_id.val
  next_conn_id.val = next_conn_id.val + 1
  sql_connections.val.set(id, payload.db)
  { id, db: payload.db }
}

///|
fn execute(payload : ExecuteRequest) -> ExecuteReply {
  match sql_connections.val.get(payload.conn_id) {
    Some(_) => { ok: true, error: None }
    None => { ok: false, error: Some("connection not found") }
  }
}

///|
fn select(payload : ExecuteRequest) -> SelectReply {
  match sql_connections.val.get(payload.conn_id) {
    Some(_) => { ok: true, rows: [payload.sql], error: None }
    None => { ok: false, rows: [], error: Some("connection not found") }
  }
}

///|
fn close_connection(conn_id : Int) -> Bool {
  let existed = sql_connections.val.contains(conn_id)
  sql_connections.val.remove(conn_id)
  existed
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("sql", plugin => {
    plugin.command_sync("load", (payload : LoadRequest) => {
      load_connection(payload)
    })
    plugin.command_sync("execute", (payload : ExecuteRequest) => {
      execute(payload)
    })
    plugin.command_sync("select", (payload : ExecuteRequest) => select(payload))
    plugin.command_sync("close", (payload : Int) => close_connection(payload))
  })
}
