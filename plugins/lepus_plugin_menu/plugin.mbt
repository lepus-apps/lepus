///|
pub struct MenuReply {
  ok : Bool
  error : String?
} derive(ToJson, FromJson)

///|
pub struct MenuIdReply {
  ok : Bool
  id : String?
  error : String?
} derive(ToJson, FromJson)

///|
pub struct MenuEventsReply {
  ok : Bool
  events : Array[String]
  error : String?
} derive(ToJson, FromJson)

///|
pub struct MenuCreateRequest {
  id : String
} derive(ToJson, FromJson)

///|
pub struct MenuSubmenuCreateRequest {
  id : String
  title : String
  enabled : Bool?
} derive(ToJson, FromJson)

///|
pub struct MenuItemCreateRequest {
  id : String
  text : String
  enabled : Bool?
  accelerator : String?
} derive(ToJson, FromJson)

///|
pub struct MenuCheckItemCreateRequest {
  id : String
  text : String
  enabled : Bool?
  checked : Bool?
  accelerator : String?
} derive(ToJson, FromJson)

///|
pub struct MenuPredefinedCreateRequest {
  id : String
  kind : String
  text : String?
} derive(ToJson, FromJson)

///|
pub struct MenuLinkRequest {
  parent_id : String
  child_id : String
} derive(ToJson, FromJson)

///|
pub struct MenuInsertRequest {
  parent_id : String
  child_id : String
  position : Int
} derive(ToJson, FromJson)

///|
pub struct MenuSetAppMenuRequest {
  id : String
} derive(ToJson, FromJson)

///|
pub struct MenuToggleRequest {
  id : String
  enabled : Bool
} derive(ToJson, FromJson)

///|
pub struct MenuCheckToggleRequest {
  id : String
  checked : Bool
} derive(ToJson, FromJson)

///|
pub struct MenuTextRequest {
  id : String
  text : String
} derive(ToJson, FromJson)

///|
pub struct MenuAcceleratorRequest {
  id : String
  accelerator : String?
} derive(ToJson, FromJson)

///|
pub struct MenuDeleteRequest {
  id : String
} derive(ToJson, FromJson)

///|
pub struct MenuBuildRequest {
  root_id : String
  clear_existing : Bool?
  set_as_app_menu : Bool?
  menus : Array[MenuCreateRequest]
  submenus : Array[MenuSubmenuCreateRequest]
  items : Array[MenuItemCreateRequest]
  check_items : Array[MenuCheckItemCreateRequest]
  predefined_items : Array[MenuPredefinedCreateRequest]
  links : Array[MenuLinkRequest]
  inserts : Array[MenuInsertRequest]
  toggles : Array[MenuToggleRequest]
  checks : Array[MenuCheckToggleRequest]
  texts : Array[MenuTextRequest]
  accelerators : Array[MenuAcceleratorRequest]
} derive(ToJson, FromJson)

///|
extern "C" fn native_menu_supported() -> Int = "lp_menu_supported"

///|
extern "C" fn native_menu_last_error() -> Bytes = "lp_menu_last_error_message"

///|
#borrow(id)
extern "C" fn native_create_menu(id : Bytes) -> Int = "lp_menu_create_menu"

///|
#borrow(id, title)
extern "C" fn native_create_submenu(
  id : Bytes,
  title : Bytes,
  enabled : Int,
) -> Int = "lp_menu_create_submenu"

///|
#borrow(id, text, accelerator)
extern "C" fn native_create_item(
  id : Bytes,
  text : Bytes,
  enabled : Int,
  accelerator : Bytes,
) -> Int = "lp_menu_create_item"

///|
#borrow(id, text, accelerator)
extern "C" fn native_create_check_item(
  id : Bytes,
  text : Bytes,
  enabled : Int,
  checked : Int,
  accelerator : Bytes,
) -> Int = "lp_menu_create_check_item"

///|
#borrow(id, kind, text)
extern "C" fn native_create_predefined_item(
  id : Bytes,
  kind : Bytes,
  text : Bytes,
) -> Int = "lp_menu_create_predefined_item"

///|
#borrow(parent_id, child_id)
extern "C" fn native_append(parent_id : Bytes, child_id : Bytes) -> Int = "lp_menu_append"

///|
#borrow(parent_id, child_id)
extern "C" fn native_insert(
  parent_id : Bytes,
  child_id : Bytes,
  position : Int,
) -> Int = "lp_menu_insert"

///|
#borrow(parent_id, child_id)
extern "C" fn native_remove(parent_id : Bytes, child_id : Bytes) -> Int = "lp_menu_remove"

///|
#borrow(id)
extern "C" fn native_set_as_app_menu(id : Bytes) -> Int = "lp_menu_set_as_app_menu"

///|
extern "C" fn native_clear_app_menu() -> Int = "lp_menu_clear_app_menu"

///|
#borrow(id)
extern "C" fn native_set_enabled(id : Bytes, enabled : Int) -> Int = "lp_menu_set_enabled"

///|
#borrow(id)
extern "C" fn native_set_checked(id : Bytes, checked : Int) -> Int = "lp_menu_set_checked"

///|
#borrow(id, text)
extern "C" fn native_set_text(id : Bytes, text : Bytes) -> Int = "lp_menu_set_text"

///|
#borrow(id, accelerator)
extern "C" fn native_set_accelerator(id : Bytes, accelerator : Bytes) -> Int = "lp_menu_set_accelerator"

///|
#borrow(id)
extern "C" fn native_delete(id : Bytes) -> Int = "lp_menu_delete"

///|
extern "C" fn native_reset() -> Int = "lp_menu_reset"

///|
extern "C" fn native_drain_events() -> Bytes = "lp_menu_drain_events"

///|
fn decode_text(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes[:])
}

///|
fn last_error(default : String) -> String {
  let message = decode_text(native_menu_last_error())
  if message.is_empty() {
    default
  } else {
    message
  }
}

///|
fn id_reply(code : Int, id : String, default_error : String) -> MenuIdReply {
  if code == 0 {
    { ok: true, id: Some(id), error: None }
  } else {
    { ok: false, id: None, error: Some(last_error(default_error)) }
  }
}

///|
fn reply(code : Int, default_error : String) -> MenuReply {
  if code == 0 {
    { ok: true, error: None }
  } else {
    { ok: false, error: Some(last_error(default_error)) }
  }
}

///|
fn encode_bool(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}

///|
fn create_menu(payload : MenuCreateRequest) -> MenuIdReply {
  id_reply(
    native_create_menu(@utf8.encode(payload.id)),
    payload.id,
    "create menu failed",
  )
}

///|
fn create_submenu(payload : MenuSubmenuCreateRequest) -> MenuIdReply {
  id_reply(
    native_create_submenu(
      @utf8.encode(payload.id),
      @utf8.encode(payload.title),
      encode_bool(payload.enabled.unwrap_or(true)),
    ),
    payload.id,
    "create submenu failed",
  )
}

///|
fn create_item(payload : MenuItemCreateRequest) -> MenuIdReply {
  id_reply(
    native_create_item(
      @utf8.encode(payload.id),
      @utf8.encode(payload.text),
      encode_bool(payload.enabled.unwrap_or(true)),
      @utf8.encode(payload.accelerator.unwrap_or("")),
    ),
    payload.id,
    "create item failed",
  )
}

///|
fn create_check_item(payload : MenuCheckItemCreateRequest) -> MenuIdReply {
  id_reply(
    native_create_check_item(
      @utf8.encode(payload.id),
      @utf8.encode(payload.text),
      encode_bool(payload.enabled.unwrap_or(true)),
      encode_bool(payload.checked.unwrap_or(false)),
      @utf8.encode(payload.accelerator.unwrap_or("")),
    ),
    payload.id,
    "create check item failed",
  )
}

///|
fn create_predefined_item(payload : MenuPredefinedCreateRequest) -> MenuIdReply {
  id_reply(
    native_create_predefined_item(
      @utf8.encode(payload.id),
      @utf8.encode(payload.kind),
      @utf8.encode(payload.text.unwrap_or("")),
    ),
    payload.id,
    "create predefined item failed",
  )
}

///|
fn build_menu(payload : MenuBuildRequest) -> MenuReply {
  if native_menu_supported() == 0 {
    return { ok: false, error: Some("menu plugin is only supported on macOS") }
  }
  if payload.clear_existing.unwrap_or(true) {
    let clear_rc = native_reset()
    if clear_rc != 0 {
      return reply(clear_rc, "reset menu failed")
    }
  }

  for req in payload.menus {
    let rc = native_create_menu(@utf8.encode(req.id))
    if rc != 0 {
      return reply(rc, "create menu failed")
    }
  }
  for req in payload.submenus {
    let rc = native_create_submenu(
      @utf8.encode(req.id),
      @utf8.encode(req.title),
      encode_bool(req.enabled.unwrap_or(true)),
    )
    if rc != 0 {
      return reply(rc, "create submenu failed")
    }
  }
  for req in payload.items {
    let rc = native_create_item(
      @utf8.encode(req.id),
      @utf8.encode(req.text),
      encode_bool(req.enabled.unwrap_or(true)),
      @utf8.encode(req.accelerator.unwrap_or("")),
    )
    if rc != 0 {
      return reply(rc, "create item failed")
    }
  }
  for req in payload.check_items {
    let rc = native_create_check_item(
      @utf8.encode(req.id),
      @utf8.encode(req.text),
      encode_bool(req.enabled.unwrap_or(true)),
      encode_bool(req.checked.unwrap_or(false)),
      @utf8.encode(req.accelerator.unwrap_or("")),
    )
    if rc != 0 {
      return reply(rc, "create check item failed")
    }
  }
  for req in payload.predefined_items {
    let rc = native_create_predefined_item(
      @utf8.encode(req.id),
      @utf8.encode(req.kind),
      @utf8.encode(req.text.unwrap_or("")),
    )
    if rc != 0 {
      return reply(rc, "create predefined item failed")
    }
  }
  for req in payload.links {
    let rc = native_append(
      @utf8.encode(req.parent_id),
      @utf8.encode(req.child_id),
    )
    if rc != 0 {
      return reply(rc, "append menu item failed")
    }
  }
  for req in payload.inserts {
    let rc = native_insert(
      @utf8.encode(req.parent_id),
      @utf8.encode(req.child_id),
      req.position,
    )
    if rc != 0 {
      return reply(rc, "insert menu item failed")
    }
  }
  for req in payload.toggles {
    let rc = native_set_enabled(@utf8.encode(req.id), encode_bool(req.enabled))
    if rc != 0 {
      return reply(rc, "set enabled failed")
    }
  }
  for req in payload.checks {
    let rc = native_set_checked(@utf8.encode(req.id), encode_bool(req.checked))
    if rc != 0 {
      return reply(rc, "set checked failed")
    }
  }
  for req in payload.texts {
    let rc = native_set_text(@utf8.encode(req.id), @utf8.encode(req.text))
    if rc != 0 {
      return reply(rc, "set text failed")
    }
  }
  for req in payload.accelerators {
    let rc = native_set_accelerator(
      @utf8.encode(req.id),
      @utf8.encode(req.accelerator.unwrap_or("")),
    )
    if rc != 0 {
      return reply(rc, "set accelerator failed")
    }
  }
  if payload.set_as_app_menu.unwrap_or(true) {
    return reply(
      native_set_as_app_menu(@utf8.encode(payload.root_id)),
      "set app menu failed",
    )
  }
  { ok: true, error: None }
}

///|
fn drain_events() -> MenuEventsReply {
  if native_menu_supported() == 0 {
    return {
      ok: false,
      events: [],
      error: Some("menu plugin is only supported on macOS"),
    }
  }
  let text = decode_text(native_drain_events())
  if text.is_empty() {
    return { ok: true, events: [], error: None }
  }
  let events = text
    .split("\n")
    .filter(item => item != "")
    .map(item => item.to_string())
    .to_array()
  { ok: true, events, error: None }
}

///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("menu", plugin => {
    plugin.command_sync("is_supported", (_ : Json) => {
      native_menu_supported() != 0
    })
    plugin.command_sync("reset", (_ : Json) => {
      reply(native_reset(), "reset menu failed")
    })
    plugin.command_sync("build_menu", (payload : MenuBuildRequest) => {
      build_menu(payload)
    })
    plugin.command_sync("clear_app_menu", (_ : Json) => {
      reply(native_clear_app_menu(), "clear app menu failed")
    })
    plugin.command_sync("create_menu", (payload : MenuCreateRequest) => {
      create_menu(payload)
    })
    plugin.command_sync("create_submenu", (payload : MenuSubmenuCreateRequest) => {
      create_submenu(payload)
    })
    plugin.command_sync("create_item", (payload : MenuItemCreateRequest) => {
      create_item(payload)
    })
    plugin.command_sync("create_check_item", (
      payload : MenuCheckItemCreateRequest,
    ) => create_check_item(payload))
    plugin.command_sync("create_predefined_item", (
      payload : MenuPredefinedCreateRequest,
    ) => create_predefined_item(payload))
    plugin.command_sync("append", (payload : MenuLinkRequest) => {
      reply(
        native_append(
          @utf8.encode(payload.parent_id),
          @utf8.encode(payload.child_id),
        ),
        "append menu item failed",
      )
    })
    plugin.command_sync("insert", (payload : MenuInsertRequest) => {
      reply(
        native_insert(
          @utf8.encode(payload.parent_id),
          @utf8.encode(payload.child_id),
          payload.position,
        ),
        "insert menu item failed",
      )
    })
    plugin.command_sync("remove", (payload : MenuLinkRequest) => {
      reply(
        native_remove(
          @utf8.encode(payload.parent_id),
          @utf8.encode(payload.child_id),
        ),
        "remove menu item failed",
      )
    })
    plugin.command_sync("set_as_app_menu", (payload : MenuSetAppMenuRequest) => {
      reply(
        native_set_as_app_menu(@utf8.encode(payload.id)),
        "set app menu failed",
      )
    })
    plugin.command_sync("set_enabled", (payload : MenuToggleRequest) => {
      reply(
        native_set_enabled(
          @utf8.encode(payload.id),
          encode_bool(payload.enabled),
        ),
        "set enabled failed",
      )
    })
    plugin.command_sync("set_checked", (payload : MenuCheckToggleRequest) => {
      reply(
        native_set_checked(
          @utf8.encode(payload.id),
          encode_bool(payload.checked),
        ),
        "set checked failed",
      )
    })
    plugin.command_sync("set_text", (payload : MenuTextRequest) => {
      reply(
        native_set_text(@utf8.encode(payload.id), @utf8.encode(payload.text)),
        "set text failed",
      )
    })
    plugin.command_sync("set_accelerator", (payload : MenuAcceleratorRequest) => {
      reply(
        native_set_accelerator(
          @utf8.encode(payload.id),
          @utf8.encode(payload.accelerator.unwrap_or("")),
        ),
        "set accelerator failed",
      )
    })
    plugin.command_sync("delete", (payload : MenuDeleteRequest) => {
      reply(native_delete(@utf8.encode(payload.id)), "delete menu entry failed")
    })
    plugin.command_sync("drain_events", (_ : Json) => drain_events())
  })
}
