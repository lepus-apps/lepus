///|
struct FetchInit {
  meth : String?
  headers : Map[String, String]?
  body : Json?
} derive(ToJson, FromJson)

///|
struct FetchReply {
  ok : Bool
  status : Int
  status_text : String
  headers : Map[String, String]
  body_text : String
  body_json : Json?
  error : String?
} derive(ToJson, FromJson)

///|
fn default_fetch_init() -> FetchInit {
  { meth: None, headers: None, body: None }
}

///|
fn parse_fetch_init(init : Json) -> FetchInit {
  match init {
    Object(obj) => {
      let meth = match obj.get("method") {
        Some(String(m)) => Some(m)
        Some(other) => Some(other.stringify())
        None => None
      }
      let headers = match obj.get("headers") {
        Some(headers_json) =>
          Some(@json.from_json(headers_json)) catch {
            _ => None
          }
        None => None
      }
      { meth, headers, body: obj.get("body") }
    }
    _ => default_fetch_init()
  }
}

///|
fn parse_fetch_payload(payload : Json) -> (String, FetchInit, String?) {
  match payload {
    String(url) => (url, default_fetch_init(), None)
    [String(url), init] => (url, parse_fetch_init(init), None)
    Object(obj) => {
      let url = match obj.get("url") {
        Some(String(url)) => url
        _ => ""
      }
      if url.is_empty() {
        ("", default_fetch_init(), Some("Invalid fetch payload: missing url"))
      } else {
        (url, parse_fetch_init(payload), None)
      }
    }
    _ => ("", default_fetch_init(), Some("Invalid fetch payload"))
  }
}

///|
fn normalize_method(meth : String?) -> String {
  match meth {
    Some(meth) => meth.trim(char_set=" \n\r\t").to_string().to_upper()
    None => "GET"
  }
}

///|
fn normalize_headers(headers : Map[String, String]?) -> Map[String, String] {
  match headers {
    Some(headers) => headers
    None => {}
  }
}

///|
fn normalize_body(body : Json?) -> String? {
  match body {
    Some(String(text)) => Some(text)
    Some(body) => Some(body.stringify())
    None => None
  }
}

///|
fn parse_response(response : @http.Response, data : &@io.Data) -> FetchReply {
  let body_text = data.text() catch { _ => "" }
  let body_json = Some(data.json()) catch { _ => None }
  {
    ok: response.code >= 200 && response.code < 300,
    status: response.code,
    status_text: response.reason,
    headers: response.headers,
    body_text,
    body_json,
    error: None,
  }
}

///|
fn fetch_error(message : String) -> FetchReply {
  {
    ok: false,
    status: 0,
    status_text: "NetworkError",
    headers: {},
    body_text: "",
    body_json: None,
    error: Some(message),
  }
}

///|
async fn fetch_with(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : String?,
) -> FetchReply {
  try {
    let (response, data) = match meth {
      "GET" =>
        match body {
          Some(body) => @http.get(url, headers~, body~)
          None => @http.get(url, headers~)
        }
      "POST" => @http.post(url, body.unwrap_or(""), headers~)
      "PUT" => @http.put(url, body.unwrap_or(""), headers~)
      _ =>
        return fetch_error(
          "Unsupported method '\{meth}'. Supported methods: GET, POST, PUT",
        )
    }
    parse_response(response, data)
  } catch {
    err => fetch_error(err.to_string())
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("http", plugin => {
    // Mimics fetch(url, init?) with one payload:
    // - "url"
    // - ["url", { method?, headers?, body? }]
    // - { url, method?, headers?, body? }
    plugin.command("fetch", (payload : Json) => {
      let (url, init, parse_error) = parse_fetch_payload(payload)
      if parse_error is Some(parse_error) {
        return fetch_error(parse_error)
      }
      let meth = normalize_method(init.meth)
      let headers = normalize_headers(init.headers)
      let body = normalize_body(init.body)
      fetch_with(url, meth, headers, body)
    })
  })
}
