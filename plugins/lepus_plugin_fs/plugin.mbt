///|
pub struct FsPathRequest {
  path : String
} derive(ToJson, FromJson)

///|
pub struct FsWriteRequest {
  path : String
  content : String
  append : Bool?
} derive(ToJson, FromJson)

///|
pub struct FsMkdirRequest {
  path : String
  recursive : Bool?
  permission : Int?
} derive(ToJson, FromJson)

///|
pub struct FsRemoveRequest {
  path : String
  recursive : Bool?
} derive(ToJson, FromJson)

///|
pub struct FsReaddirRequest {
  path : String
  include_hidden : Bool?
  include_special : Bool?
  sort : Bool?
} derive(ToJson, FromJson)

///|
pub struct FsTmpdirRequest {
  prefix : String?
} derive(ToJson, FromJson)

///|
pub struct FsBoolReply {
  ok : Bool
  value : Bool
  error : String?
} derive(ToJson, FromJson)

///|
pub struct FsStringReply {
  ok : Bool
  value : String?
  error : String?
} derive(ToJson, FromJson)

///|
pub struct FsReadReply {
  ok : Bool
  content : String?
  error : String?
} derive(ToJson, FromJson)

///|
pub struct FsListReply {
  ok : Bool
  entries : Array[String]
  error : String?
} derive(ToJson, FromJson)

///|
pub struct FsReply {
  ok : Bool
  error : String?
} derive(ToJson, FromJson)

///|
pub struct FsStatReply {
  ok : Bool
  exists : Bool
  kind : String?
  can_read : Bool?
  can_write : Bool?
  can_execute : Bool?
  error : String?
} derive(ToJson, FromJson)

///|
fn kind_name(kind : @fs.FileKind) -> String {
  match kind {
    @fs.FileKind::Unknown => "unknown"
    @fs.FileKind::Regular => "regular"
    @fs.FileKind::Directory => "directory"
    @fs.FileKind::SymLink => "symlink"
    @fs.FileKind::Socket => "socket"
    @fs.FileKind::Pipe => "pipe"
    @fs.FileKind::BlockDevice => "block_device"
    @fs.FileKind::CharDevice => "char_device"
  }
}

///|
async fn exists_reply(path : String) -> FsBoolReply {
  { ok: true, value: @fs.exists(path), error: None } catch {
    _ => { ok: false, value: false, error: Some("exists failed") }
  }
}

///|
async fn read_text(payload : FsPathRequest) -> FsReadReply {
  { ok: true, content: Some(@fs.read_file(payload.path).text()), error: None } catch {
    _ => { ok: false, content: None, error: Some("read failed") }
  }
}

///|
async fn write_text(payload : FsWriteRequest) -> FsReply {
  try {
    @fs.write_file(
      payload.path,
      payload.content,
      append=payload.append.unwrap_or(false),
      create=0o644,
      truncate=!payload.append.unwrap_or(false),
    )
    { ok: true, error: None }
  } catch {
    _ => { ok: false, error: Some("write failed") }
  }
}

///|
async fn mkdir_reply(payload : FsMkdirRequest) -> FsReply {
  try {
    @fs.mkdir(
      payload.path,
      recursive=payload.recursive.unwrap_or(true),
      permission=payload.permission.unwrap_or(0o755),
    )
    { ok: true, error: None }
  } catch {
    _ => { ok: false, error: Some("mkdir failed") }
  }
}

///|
async fn remove_reply(payload : FsRemoveRequest) -> FsReply {
  try {
    let recursive = payload.recursive.unwrap_or(false)
    if recursive {
      @fs.rmdir(payload.path, recursive=true)
    } else {
      @fs.remove(payload.path)
    }
    { ok: true, error: None }
  } catch {
    _ => { ok: false, error: Some("remove failed") }
  }
}

///|
async fn readdir_reply(payload : FsReaddirRequest) -> FsListReply {
  {
    ok: true,
    entries: @fs.readdir(
      payload.path,
      include_hidden=payload.include_hidden.unwrap_or(false),
      include_special=payload.include_special.unwrap_or(false),
      sort=payload.sort.unwrap_or(true),
    ),
    error: None,
  } catch {
    _ => { ok: false, entries: [], error: Some("readdir failed") }
  }
}

///|
async fn realpath_reply(payload : FsPathRequest) -> FsStringReply {
  { ok: true, value: Some(@fs.realpath(payload.path)), error: None } catch {
    _ => { ok: false, value: None, error: Some("realpath failed") }
  }
}

///|
async fn tmpdir_reply(payload : FsTmpdirRequest) -> FsStringReply {
  {
    ok: true,
    value: Some(@fs.tmpdir(prefix=payload.prefix.unwrap_or("lepus-fs"))),
    error: None,
  } catch {
    _ => { ok: false, value: None, error: Some("tmpdir failed") }
  }
}

///|
async fn stat_reply(payload : FsPathRequest) -> FsStatReply {
  try {
    if !@fs.exists(payload.path) {
      return {
        ok: true,
        exists: false,
        kind: None,
        can_read: None,
        can_write: None,
        can_execute: None,
        error: None,
      }
    }
    {
      ok: true,
      exists: true,
      kind: Some(kind_name(@fs.kind(payload.path))),
      can_read: Some(@fs.can_read(payload.path)),
      can_write: Some(@fs.can_write(payload.path)),
      can_execute: Some(@fs.can_execute(payload.path)),
      error: None,
    }
  } catch {
    _ =>
      {
        ok: false,
        exists: false,
        kind: None,
        can_read: None,
        can_write: None,
        can_execute: None,
        error: Some("stat failed"),
      }
  }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("fs", plugin => {
    plugin.command("exists", (payload : String) => exists_reply(payload))
    plugin.command("read_text", (payload : FsPathRequest) => read_text(payload))
    plugin.command("write_text", (payload : FsWriteRequest) => {
      write_text(payload)
    })
    plugin.command("mkdir", (payload : FsMkdirRequest) => mkdir_reply(payload))
    plugin.command("remove", (payload : FsRemoveRequest) => {
      remove_reply(payload)
    })
    plugin.command("readdir", (payload : FsReaddirRequest) => {
      readdir_reply(payload)
    })
    plugin.command("realpath", (payload : FsPathRequest) => {
      realpath_reply(payload)
    })
    plugin.command("tmpdir", (payload : FsTmpdirRequest) => {
      tmpdir_reply(payload)
    })
    plugin.command("stat", (payload : FsPathRequest) => stat_reply(payload))
  })
}
