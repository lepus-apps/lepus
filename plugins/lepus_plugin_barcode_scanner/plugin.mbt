///|
pub enum BarcodeFormat {
  Unknown
  Ean13
  QrLike
} derive(ToJson, FromJson, Debug, Eq)

///|
pub struct ScanResult {
  value : String
  format : BarcodeFormat
  valid : Bool
} derive(ToJson, FromJson)

///|
fn is_all_digits(text : String) -> Bool {
  let chars = text.to_array()
  let mut ok = true
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if c < '0' || c > '9' {
      ok = false
      break
    }
  }
  ok
}

///|
fn ean13_valid(text : String) -> Bool {
  guard text.length() == 13 && is_all_digits(text) else { false }
  let nums = text.to_array()
  let mut sum = 0
  for i = 0; i < 12; i = i + 1 {
    let digit = nums[i].to_int() - '0'.to_int()
    if i % 2 == 0 {
      sum = sum + digit
    } else {
      sum = sum + digit * 3
    }
  }
  let check = (10 - sum % 10) % 10
  let last = nums[12].to_int() - '0'.to_int()
  check == last
}

///|
pub fn scan(text : String) -> ScanResult {
  let trimmed = text.trim(char_set=" \n\r\t").to_string()
  if trimmed.length() == 13 && is_all_digits(trimmed) {
    {
      value: trimmed,
      format: BarcodeFormat::Ean13,
      valid: ean13_valid(trimmed),
    }
  } else if trimmed.length() >= 6 {
    { value: trimmed, format: BarcodeFormat::QrLike, valid: true }
  } else {
    { value: trimmed, format: BarcodeFormat::Unknown, valid: false }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("barcode_scanner", plugin => {
    plugin.command_sync("scan", (payload : String) => scan(payload))
    plugin.command_sync("validate_ean13", (payload : String) => {
      ean13_valid(payload)
    })
  })
}
