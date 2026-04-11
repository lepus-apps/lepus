///|
pub struct ScopeSetRequest {
  scope : String
  key : String
  value : String
} derive(ToJson, FromJson)

///|
pub struct ScopeGetRequest {
  scope : String
  key : String
} derive(ToJson, FromJson)

///|
let scope_store : Ref[Map[String, Map[String, String]]] = { val: {} }

///|
fn ensure_scope(scope : String) -> Map[String, String] {
  match scope_store.val.get(scope) {
    Some(existing) => existing
    None => {
      let created : Map[String, String] = {}
      scope_store.val.set(scope, created)
      created
    }
  }
}

///|
fn set_value(payload : ScopeSetRequest) -> Bool {
  let table = ensure_scope(payload.scope)
  table.set(payload.key, payload.value)
  true
}

///|
fn get_value(payload : ScopeGetRequest) -> String? {
  match scope_store.val.get(payload.scope) {
    Some(table) => table.get(payload.key)
    None => None
  }
}

///|
fn remove_value(payload : ScopeGetRequest) -> Bool {
  match scope_store.val.get(payload.scope) {
    Some(table) => {
      let existed = table.contains(payload.key)
      table.remove(payload.key)
      existed
    }
    None => false
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("persisted_scope", plugin => {
    plugin.command_sync("set", (payload : ScopeSetRequest) => set_value(payload))
    plugin.command_sync("get", (payload : ScopeGetRequest) => get_value(payload))
    plugin.command_sync("remove", (payload : ScopeGetRequest) => {
      remove_value(payload)
    })
  })
}
