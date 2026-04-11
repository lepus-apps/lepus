///|
pub struct DeepLinkBuildRequest {
  scheme : String
  host : String?
  path : String?
  query : Map[String, String]?
} derive(ToJson, FromJson)

///|
pub struct DeepLinkParts {
  scheme : String
  host : String?
  path : String
  query : Map[String, String]
} derive(ToJson, FromJson)

///|
fn split_once(text : String, needle : Char) -> (String, String?) {
  let chars = text.to_array()
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == needle {
      return (text[:i].to_string(), Some(text[i + 1:].to_string()))
    }
  }
  (text, None)
}

///|
fn parse_query(text : String) -> Map[String, String] {
  let out : Map[String, String] = {}
  let mut rest = text
  while !rest.is_empty() {
    let (part, next) = split_once(rest, '&')
    let (k, v) = split_once(part, '=')
    match v {
      Some(value) => out.set(k, value)
      None => ()
    }
    rest = next.unwrap_or("")
  }
  out
}

///|
pub fn parse(url : String) -> DeepLinkParts {
  let (scheme, after_scheme) = split_once(url, ':')
  let payload = after_scheme.unwrap_or("")
  let payload1 = if payload.has_prefix("//") {
    payload[2:].to_string()
  } else {
    payload
  }
  let (before_query, query_text) = split_once(payload1, '?')
  let (host_text, path_text) = split_once(before_query, '/')
  let host = if host_text.is_empty() { None } else { Some(host_text) }
  let path = "/" + path_text.unwrap_or("")
  { scheme, host, path, query: parse_query(query_text.unwrap_or("")) }
}

///|
pub fn build(payload : DeepLinkBuildRequest) -> String {
  let host = payload.host.unwrap_or("")
  let path = payload.path.unwrap_or("/")
  let base = payload.scheme + "://" + host + path
  match payload.query {
    Some(query) => {
      let pairs : Array[String] = []
      for key, value in query {
        pairs.push(key + "=" + value)
      }
      if pairs.length() == 0 {
        base
      } else {
        base + "?" + pairs.join("&")
      }
    }
    None => base
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("deep_link", plugin => {
    plugin.command_sync("parse", (payload : String) => parse(payload))
    plugin.command_sync("build", (payload : DeepLinkBuildRequest) => {
      build(payload)
    })
  })
}
