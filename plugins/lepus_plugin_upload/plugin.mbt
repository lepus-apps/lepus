///|
pub struct UploadSaveRequest {
  filename : String
  content : String
} derive(ToJson, FromJson)

///|
pub struct UploadSaveReply {
  ok : Bool
  path : String?
  error : String?
} derive(ToJson, FromJson)

///|
pub struct UploadDeleteReply {
  ok : Bool
  error : String?
} derive(ToJson, FromJson)

///|
fn sanitize_filename(filename : String) -> String {
  let chars = filename.to_array()
  let out = StringBuilder::new()
  for i = 0; i < chars.length(); i = i + 1 {
    let ch = chars[i]
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '.' ||
      ch == '-' ||
      ch == '_' {
      out.write_char(ch)
    } else {
      out.write_char('_')
    }
  }
  let s = out.to_string()
  if s.is_empty() {
    "upload.txt"
  } else {
    s
  }
}

///|
async fn save_text(payload : UploadSaveRequest) -> UploadSaveReply {
  try {
    let dir = @fs.tmpdir(prefix="lepus-upload")
    @fs.mkdir(dir, recursive=true, permission=0o755)
    let safe_name = sanitize_filename(payload.filename)
    let path = dir + "/" + safe_name
    @fs.write_file(path, payload.content, create=0o644, truncate=true)
    { ok: true, path: Some(path), error: None }
  } catch {
    _ => { ok: false, path: None, error: Some("save upload failed") }
  }
}

///|
async fn delete_file(path : String) -> UploadDeleteReply {
  try {
    @fs.remove(path)
    { ok: true, error: None }
  } catch {
    _ => { ok: false, error: Some("delete upload failed") }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("upload", plugin => {
    plugin.command("save_text", (payload : UploadSaveRequest) => {
      save_text(payload)
    })
    plugin.command("delete", (payload : String) => delete_file(payload))
  })
}
