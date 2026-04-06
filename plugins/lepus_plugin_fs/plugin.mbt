///|
priv struct PathRequest {
  path : String
} derive(FromJson)

///|
priv struct WriteTextFileRequest {
  path : String
  contents : String
} derive(FromJson)

///|
priv struct RecursivePathRequest {
  path : String
  recursive : Bool?
} derive(FromJson)

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("fs", fn(context) {
    @lepus_plugin_support.command_result_async(
      context, "_exists", exists_command,
    )
    @lepus_plugin_support.command_result_async(
      context, "_readTextFile", read_text_file_command,
    )
    @lepus_plugin_support.command_result_async(
      context, "_writeTextFile", write_text_file_command,
    )
    @lepus_plugin_support.command_result_async(context, "_mkdir", mkdir_command)
    @lepus_plugin_support.command_result_async(
      context, "_remove", remove_command,
    )
    @lepus_plugin_support.install_js_initializer(context, fs_api_script())
  })
}

///|
fn fs_api_script() -> String {
  (
    #|plugin.exists = function(path){
    #|  return plugin._exists({ path: path });
    #|};
    #|plugin.readTextFile = function(path){
    #|  return plugin._readTextFile({ path: path });
    #|};
    #|plugin.writeTextFile = function(path, contents){
    #|  return plugin._writeTextFile({ path: path, contents: contents });
    #|};
    #|plugin.mkdir = function(path, options){
    #|  const recursive = !!(options && options.recursive);
    #|  return plugin._mkdir({ path: path, recursive: recursive });
    #|};
    #|plugin.remove = function(path, options){
    #|  const recursive = !!(options && options.recursive);
    #|  return plugin._remove({ path: path, recursive: recursive });
    #|};
    #|plugin.example = async function(){
    #|  const base = '.lepus-fs-plugin-example';
    #|  const file = base + '/sample.txt';
    #|  await plugin.mkdir(base, { recursive: true });
    #|  await plugin.writeTextFile(file, 'hello from lepus fs plugin');
    #|  const existsBeforeRemove = await plugin.exists(file);
    #|  const text = await plugin.readTextFile(file);
    #|  await plugin.remove(file);
    #|  await plugin.remove(base);
    #|  const existsAfterRemove = await plugin.exists(file);
    #|  return { baseDir: base, file: file, existsBeforeRemove: existsBeforeRemove, text: text, existsAfterRemove: existsAfterRemove };
    #|};
  )
}

///|
fn ensure_path(path : String, api_name : String) -> Result[String, String] {
  if path == "" {
    Err(api_name + ": path must not be empty")
  } else {
    Ok(path)
  }
}

///|
fn io_error(api_name : String, err : Error) -> String {
  api_name + ": " + err.to_string()
}

///|
async fn exists_checked(
  path : String,
  api_name : String,
) -> Result[Bool, String] {
  Ok(@fs.exists(path)) catch {
    err => Err(io_error(api_name, err))
  }
}

///|
async fn is_dir_checked(
  path : String,
  api_name : String,
) -> Result[Bool, String] {
  Ok(@fs.kind(path) is @fs.FileKind::Directory) catch {
    err => Err(io_error(api_name, err))
  }
}

///|
async fn is_dir_if_exists(
  path : String,
  api_name : String,
) -> Result[Bool, String] {
  match exists_checked(path, api_name) {
    Err(err) => Err(err)
    Ok(false) => Ok(false)
    Ok(true) => is_dir_checked(path, api_name)
  }
}

///|
async fn exists_command(request : PathRequest) -> Result[Bool, String] {
  match ensure_path(request.path, "exists") {
    Err(err) => Err(err)
    Ok(path) => exists_checked(path, "exists")
  }
}

///|
async fn read_text_file_command(
  request : PathRequest,
) -> Result[String, String] {
  match ensure_path(request.path, "readTextFile") {
    Err(err) => Err(err)
    Ok(path) =>
      match exists_checked(path, "readTextFile") {
        Err(err) => Err(err)
        Ok(false) => Err("readTextFile: path does not exist: " + path)
        Ok(true) =>
          match is_dir_checked(path, "readTextFile") {
            Err(err) => Err(err)
            Ok(true) => Err("readTextFile: path is a directory: " + path)
            Ok(false) =>
              Ok(@fs.read_file(path).text()) catch {
                err => Err(io_error("readTextFile", err))
              }
          }
      }
  }
}

///|
async fn write_text_file_command(
  request : WriteTextFileRequest,
) -> Result[Bool, String] {
  match ensure_path(request.path, "writeTextFile") {
    Err(err) => Err(err)
    Ok(path) =>
      match is_dir_if_exists(path, "writeTextFile") {
        Err(err) => Err(err)
        Ok(true) => Err("writeTextFile: path is a directory: " + path)
        Ok(false) =>
          try {
            @fs.write_file(path, request.contents, create=0o644, truncate=true)
            Ok(true)
          } catch {
            err => Err(io_error("writeTextFile", err))
          }
      }
  }
}

///|
async fn mkdir_command(request : RecursivePathRequest) -> Result[Bool, String] {
  match ensure_path(request.path, "mkdir") {
    Err(err) => Err(err)
    Ok(path) => {
      let recursive = request.recursive.unwrap_or(false)
      try {
        @fs.mkdir(path, permission=0o755, recursive~)
        Ok(true)
      } catch {
        err => Err(io_error("mkdir", err))
      }
    }
  }
}

///|
async fn remove_command(request : RecursivePathRequest) -> Result[Bool, String] {
  match ensure_path(request.path, "remove") {
    Err(err) => Err(err)
    Ok(path) => {
      let recursive = request.recursive.unwrap_or(false)
      match exists_checked(path, "remove") {
        Err(err) => Err(err)
        Ok(false) => Err("remove: path does not exist: " + path)
        Ok(true) =>
          match is_dir_checked(path, "remove") {
            Err(err) => Err(err)
            Ok(true) =>
              try {
                @fs.rmdir(path, recursive~)
                Ok(true)
              } catch {
                err => Err(io_error("remove", err))
              }
            Ok(false) =>
              try {
                @fs.remove(path)
                Ok(true)
              } catch {
                err => Err(io_error("remove", err))
              }
          }
      }
    }
  }
}

///|
async fn remove_if_exists(path : String) -> Unit {
  try {
    if @fs.exists(path) {
      if @fs.kind(path) is @fs.FileKind::Directory {
        @fs.rmdir(path, recursive=true)
      } else {
        @fs.remove(path)
      }
    }
  } catch {
    _ => ()
  }
}

///|
async test "fs plugin validates empty path" {
  assert_eq(
    exists_command(PathRequest::{ path: "" }),
    Err("exists: path must not be empty"),
  )
}

///|
async test "fs plugin read/write roundtrip" {
  let root = ".lepus-fs-plugin-test"
  let file = root + "/roundtrip.txt"
  remove_if_exists(root)
  assert_eq(
    mkdir_command(RecursivePathRequest::{ path: root, recursive: Some(true) }),
    Ok(true),
  )
  assert_eq(
    write_text_file_command(WriteTextFileRequest::{
      path: file,
      contents: "hello fs plugin",
    }),
    Ok(true),
  )
  assert_eq(exists_command(PathRequest::{ path: file }), Ok(true))
  assert_eq(
    read_text_file_command(PathRequest::{ path: file }),
    Ok("hello fs plugin"),
  )
  assert_eq(
    remove_command(RecursivePathRequest::{ path: file, recursive: Some(false) }),
    Ok(true),
  )
  assert_eq(exists_command(PathRequest::{ path: file }), Ok(false))
  assert_eq(
    remove_command(RecursivePathRequest::{ path: root, recursive: Some(false) }),
    Ok(true),
  )
}

///|
async test "fs plugin recursive remove handles nested directories" {
  let root = ".lepus-fs-plugin-rm-test"
  let nested_dir = root + "/a/b"
  let nested_file = nested_dir + "/x.txt"
  remove_if_exists(root)
  assert_eq(
    mkdir_command(RecursivePathRequest::{
      path: nested_dir,
      recursive: Some(true),
    }),
    Ok(true),
  )
  assert_eq(
    write_text_file_command(WriteTextFileRequest::{
      path: nested_file,
      contents: "nested",
    }),
    Ok(true),
  )
  assert_eq(
    remove_command(RecursivePathRequest::{ path: root, recursive: Some(true) }),
    Ok(true),
  )
  assert_eq(exists_command(PathRequest::{ path: root }), Ok(false))
}
