///|
pub struct NfcEncodeRequest {
  text : String
} derive(ToJson, FromJson)

///|
pub struct NfcDecodeRequest {
  hex : String
} derive(ToJson, FromJson)

///|
pub struct NfcFrame {
  ok : Bool
  hex : String
  text : String?
  error : String?
} derive(ToJson, FromJson)

///|
fn nibble_to_hex(n : Int) -> Char {
  let code = if n < 10 { '0'.to_int() + n } else { 'A'.to_int() + n - 10 }
  code.unsafe_to_char()
}

///|
fn to_hex(text : String) -> String {
  let out = StringBuilder::new()
  let chars = text.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    let code = chars[i].to_int()
    out.write_char(nibble_to_hex(code / 16))
    out.write_char(nibble_to_hex(code % 16))
  }
  out.to_string()
}

///|
fn hex_digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - '0'.to_int())
  } else if c >= 'A' && c <= 'F' {
    Some(10 + c.to_int() - 'A'.to_int())
  } else if c >= 'a' && c <= 'f' {
    Some(10 + c.to_int() - 'a'.to_int())
  } else {
    None
  }
}

///|
fn decode_hex(hex : String) -> Result[String, String] {
  let trimmed = hex.trim(char_set=" \n\r\t").to_string()
  let chars = trimmed.to_array()
  if chars.length() == 0 {
    return Ok("")
  }
  if chars.length() % 2 != 0 {
    return Err("hex length must be even")
  }
  let out = StringBuilder::new()
  for i = 0; i + 1 < chars.length(); i = i + 2 {
    let hi = match hex_digit(chars[i]) {
      Some(v) => v
      None => return Err("invalid hex digit at index \{i}")
    }
    let lo = match hex_digit(chars[i + 1]) {
      Some(v) => v
      None => return Err("invalid hex digit at index \{i + 1}")
    }
    out.write_char((hi * 16 + lo).unsafe_to_char())
  }
  Ok(out.to_string())
}

///|
fn encode_frame(payload : NfcEncodeRequest) -> NfcFrame {
  { ok: true, hex: to_hex(payload.text), text: Some(payload.text), error: None }
}

///|
fn decode_frame(payload : NfcDecodeRequest) -> NfcFrame {
  match decode_hex(payload.hex) {
    Ok(text) => { ok: true, hex: payload.hex, text: Some(text), error: None }
    Err(message) =>
      { ok: false, hex: payload.hex, text: None, error: Some(message) }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("nfc", plugin => {
    plugin.command_sync("encode", (payload : NfcEncodeRequest) => {
      encode_frame(payload)
    })
    plugin.command_sync("decode", (payload : NfcDecodeRequest) => {
      decode_frame(payload)
    })
  })
}
