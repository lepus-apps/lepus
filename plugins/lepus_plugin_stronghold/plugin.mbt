///|
pub struct SecretSetRequest {
  key : String
  value : String
} derive(ToJson, FromJson)

///|
let secret_key : Ref[String] = { val: "lepus-stronghold" }

///|
let encrypted_store : Ref[Map[String, String]] = { val: {} }

///|
fn xor_encrypt(text : String, key : String) -> String {
  let chars = text.to_array()
  let keys = key.to_array()
  if keys.length() == 0 {
    return text
  }
  let out = StringBuilder::new()
  for i = 0; i < chars.length(); i = i + 1 {
    let x = chars[i].to_int() ^ keys[i % keys.length()].to_int()
    out.write_char((x % 95 + 32).unsafe_to_char())
  }
  out.to_string()
}

///|
fn set_secret(payload : SecretSetRequest) -> Bool {
  encrypted_store.val.set(
    payload.key,
    xor_encrypt(payload.value, secret_key.val),
  )
  true
}

///|
fn get_secret(key : String) -> String? {
  match encrypted_store.val.get(key) {
    Some(raw) => Some(xor_encrypt(raw, secret_key.val))
    None => None
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("stronghold", plugin => {
    plugin.command_sync("set", (payload : SecretSetRequest) => {
      set_secret(payload)
    })
    plugin.command_sync("get", (payload : String) => get_secret(payload))
    plugin.command_sync("set_key", (payload : String) => {
      secret_key.val = payload
      true
    })
  })
}
