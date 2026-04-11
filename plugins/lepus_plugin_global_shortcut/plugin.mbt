///|
pub struct ShortcutBinding {
  accelerator : String
  action : String
} derive(ToJson, FromJson)

///|
let shortcut_bindings : Ref[Map[String, String]] = { val: {} }

///|
fn register_shortcut(payload : ShortcutBinding) -> Bool {
  shortcut_bindings.val.set(payload.accelerator, payload.action)
  true
}

///|
fn unregister_shortcut(accelerator : String) -> Bool {
  let existed = shortcut_bindings.val.contains(accelerator)
  shortcut_bindings.val.remove(accelerator)
  existed
}

///|
fn list_shortcuts() -> Array[ShortcutBinding] {
  let result : Array[ShortcutBinding] = []
  for accelerator, action in shortcut_bindings.val {
    result.push({ accelerator, action })
  }
  result
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("global-shortcut", plugin => {
    plugin.command_sync("register", (payload : ShortcutBinding) => {
      register_shortcut(payload)
    })
    plugin.command_sync("unregister", (payload : String) => {
      unregister_shortcut(payload)
    })
    plugin.command_sync("list", (_ : Json) => list_shortcuts())
  })
}
