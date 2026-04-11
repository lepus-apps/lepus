///|
pub struct StoreSetRequest {
  key : String
  value : String
} derive(ToJson, FromJson)

///|
pub struct StoreDump {
  entries : Map[String, String]
} derive(ToJson, FromJson)

///|
let store_map : Ref[Map[String, String]] = { val: {} }

///|
fn set_item(payload : StoreSetRequest) -> Bool {
  store_map.val.set(payload.key, payload.value)
  true
}

///|
fn get_item(key : String) -> String? {
  store_map.val.get(key)
}

///|
fn clear_all() -> Bool {
  store_map.val = {}
  true
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("store", plugin => {
    plugin.command_sync("set", (payload : StoreSetRequest) => set_item(payload))
    plugin.command_sync("get", (payload : String) => get_item(payload))
    plugin.command_sync("remove", (payload : String) => {
      let existed = store_map.val.contains(payload)
      store_map.val.remove(payload)
      existed
    })
    plugin.command_sync("dump", (_ : Json) => StoreDump::{
      entries: store_map.val,
    })
    plugin.command_sync("clear", (_ : Json) => clear_all())
  })
}
