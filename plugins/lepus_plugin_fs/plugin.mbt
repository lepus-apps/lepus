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
    context.command_result("_exists", exists_command)
    context.command_result("_readTextFile", read_text_file_command)
    context.command_result("_writeTextFile", write_text_file_command)
    context.command_result("_mkdir", mkdir_command)
    context.command_result("_remove", remove_command)
    @lepus_plugin_support.install_js_initializer(
      context,
      fs_api_script(),
    )
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
fn exists_command(request : PathRequest) -> Result[Bool, String] {
  match ensure_path(request.path, "exists") {
    Err(err) => Err(err)
    Ok(path) => Ok(fs_exists(path))
  }
}

///|
fn read_text_file_command(request : PathRequest) -> Result[String, String] {
  match ensure_path(request.path, "readTextFile") {
    Err(err) => Err(err)
    Ok(path) => {
      guard fs_exists(path) else {
        return Err("readTextFile: path does not exist: " + path)
      }
      guard !fs_is_dir(path) else {
        return Err("readTextFile: path is a directory: " + path)
      }
      match fs_read_text(path) {
        Ok(content) => Ok(content)
        Err(err) => Err("readTextFile: " + err)
      }
    }
  }
}

///|
fn write_text_file_command(
  request : WriteTextFileRequest,
) -> Result[Bool, String] {
  match ensure_path(request.path, "writeTextFile") {
    Err(err) => Err(err)
    Ok(path) => {
      guard !fs_is_dir(path) else {
        return Err("writeTextFile: path is a directory: " + path)
      }
      match fs_write_text(path, request.contents) {
        Ok(_) => Ok(true)
        Err(err) => Err("writeTextFile: " + err)
      }
    }
  }
}

///|
fn mkdir_command(request : RecursivePathRequest) -> Result[Bool, String] {
  match ensure_path(request.path, "mkdir") {
    Err(err) => Err(err)
    Ok(path) => {
      let recursive = request.recursive.unwrap_or(false)
      match fs_mkdir(path, recursive) {
        Ok(_) => Ok(true)
        Err(err) => Err("mkdir: " + err)
      }
    }
  }
}

///|
fn remove_command(request : RecursivePathRequest) -> Result[Bool, String] {
  match ensure_path(request.path, "remove") {
    Err(err) => Err(err)
    Ok(path) => {
      let recursive = request.recursive.unwrap_or(false)
      match fs_remove(path, recursive) {
        Ok(_) => Ok(true)
        Err(err) => Err("remove: " + err)
      }
    }
  }
}

///|
test "fs plugin validates empty path" {
  assert_eq(
    exists_command(PathRequest::{ path: "" }),
    Err("exists: path must not be empty"),
  )
}

///|
test "fs plugin read/write roundtrip" {
  let root = ".lepus-fs-plugin-test"
  let file = root + "/roundtrip.txt"
  ignore(fs_remove(root, true))
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
test "fs plugin recursive remove handles nested directories" {
  let root = ".lepus-fs-plugin-rm-test"
  let nested_dir = root + "/a/b"
  let nested_file = nested_dir + "/x.txt"
  ignore(fs_remove(root, true))
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
