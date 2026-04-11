///|
pub struct BiometricAuthRequest {
  reason : String?
} derive(ToJson, FromJson)

///|
pub struct BiometricAuthReply {
  available : Bool
  success : Bool
  reason : String
  error : String?
} derive(ToJson, FromJson)

///|
pub fn authenticate(payload : BiometricAuthRequest) -> BiometricAuthReply {
  let reason = payload.reason.unwrap_or("Authenticate")
  if !is_available() {
    {
      available: false,
      success: false,
      reason,
      error: Some("Biometric is not available on this platform"),
    }
  } else {
    match authenticate_native(reason) {
      Ok(success) => { available: true, success, reason, error: None }
      Err(message) =>
        { available: true, success: false, reason, error: Some(message) }
    }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("biometric", plugin => {
    plugin.command_sync("is_available", (_ : Json) => is_available())
    plugin.command_sync("authenticate", (payload : BiometricAuthRequest) => {
      authenticate(payload)
    })
  })
}
