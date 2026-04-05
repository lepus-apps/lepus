///|
pub fn join_path(base : String, leaf : String) -> String {
  if base.has_suffix("/") {
    base + leaf
  } else {
    base + "/" + leaf
  }
}

///|
pub fn resolve_path(base : String, path : String?) -> String {
  match path {
    Some(path) =>
      if is_absolute_path(path) {
        path
      } else {
        join_path(base, path)
      }
    None => base
  }
}

///|
pub fn project_basename(project_name : String) -> String {
  let parts = project_name.split("/").map(part => part.to_string()).to_array()
  parts.last().unwrap_or(project_name)
}

///|
pub fn moonbit_string_literal(value : String) -> String {
  "\"" + escape_moonbit_string(value) + "\""
}

///|
pub fn embed_module_source(content : String) -> String {
  "///|\n" + "pub let resource = " + moonbit_string_literal(content) + "\n"
}

///|
fn escape_moonbit_string(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t")
}

///|
fn is_absolute_path(path : String) -> Bool {
  path.has_prefix("/") || is_windows_absolute_path(path)
}

///|
fn is_windows_absolute_path(path : String) -> Bool {
  if path.length() < 3 {
    return false
  }
  let drive = path[0]
  let colon = path[1]
  let sep = path[2]
  is_ascii_letter(drive) && colon == ':' && (sep == '/' || sep == '\\')
}

///|
fn is_ascii_letter(char : UInt16) -> Bool {
  (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z')
}
