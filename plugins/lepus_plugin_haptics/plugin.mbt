///|
pub struct HapticPulseRequest {
  pattern : String
  intensity : Int?
} derive(ToJson, FromJson)

///|
pub struct HapticPulseReply {
  ok : Bool
  pattern : String
  intensity : Int
  error : String?
} derive(ToJson, FromJson)

///|
fn pulse(payload : HapticPulseRequest) -> HapticPulseReply {
  let mut intensity = payload.intensity.unwrap_or(50)
  if intensity < 0 {
    intensity = 0
  } else if intensity > 100 {
    intensity = 100
  }
  match pulse_native(intensity) {
    Ok(_) => { ok: true, pattern: payload.pattern, intensity, error: None }
    Err(message) =>
      { ok: false, pattern: payload.pattern, intensity, error: Some(message) }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("haptics", plugin => {
    plugin.command_sync("pulse", (payload : HapticPulseRequest) => {
      pulse(payload)
    })
  })
}
