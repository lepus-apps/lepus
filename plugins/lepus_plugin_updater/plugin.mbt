///|
pub struct UpdateCheckRequest {
  current : String
  latest : String
} derive(ToJson, FromJson)

///|
pub struct UpdateCheckReply {
  has_update : Bool
  current : String
  latest : String
} derive(ToJson, FromJson)

///|
fn parse_part(text : String) -> Int {
  let chars = text.to_array()
  let mut value = 0
  for i = 0; i < chars.length(); i = i + 1 {
    let c = chars[i]
    if c < '0' || c > '9' {
      break
    }
    value = value * 10 + (c.to_int() - '0'.to_int())
  }
  value
}

///|
fn parse_version_parts(version : String) -> Array[Int] {
  let out : Array[Int] = []
  let mut rest = version
  while true {
    let chars = rest.to_array()
    let mut idx = -1
    for i = 0; i < chars.length(); i = i + 1 {
      if chars[i] == '.' {
        idx = i
        break
      }
    }
    if idx < 0 {
      out.push(parse_part(rest))
      break
    }
    out.push(parse_part(rest[:idx].to_string()))
    rest = rest[idx + 1:].to_string()
  }
  out
}

///|
pub fn compare_versions(a : String, b : String) -> Int {
  let av = parse_version_parts(a)
  let bv = parse_version_parts(b)
  let n = if av.length() > bv.length() { av.length() } else { bv.length() }
  for i = 0; i < n; i = i + 1 {
    let x = av.get(i).unwrap_or(0)
    let y = bv.get(i).unwrap_or(0)
    if x < y {
      return -1
    }
    if x > y {
      return 1
    }
  }
  0
}

///|
pub fn check_update(payload : UpdateCheckRequest) -> UpdateCheckReply {
  {
    has_update: compare_versions(payload.current, payload.latest) < 0,
    current: payload.current,
    latest: payload.latest,
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("updater", plugin => {
    plugin.command_sync("check", (payload : UpdateCheckRequest) => {
      check_update(payload)
    })
  })
}
