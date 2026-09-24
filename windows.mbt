// Label-addressed window manager.
//
// `WindowRegistry` maps each window label to its globally-unique window id and
// gives any window the ability to open, close, show, hide, move, resize,
// minimize, maximize or fullscreen any other window by its stable label.
//
// The plugin lives in the **main process** (like `EventBus`). Commands resolve
// a label to a window id and issue the corresponding `wm_*` call on the main
// process `WindowManager`. Lazy windows — declared with `WindowConfig.hidden`
// — are not spawned up front; `open` spawns their child process on first use.

///|
/// Snapshot of one managed window returned by the `windows` plugin `list` API.
pub struct WindowInfo {
  label : String
  open : Bool
} derive(ToJson, FromJson)

///|
/// Target window label request.
pub struct LabelRequest {
  label : String
} derive(ToJson, FromJson)

///|
/// Move a target window to an absolute position.
pub struct MoveWindowRequest {
  label : String
  x : Int
  y : Int
} derive(ToJson, FromJson)

///|
/// Resize a target window.
pub struct ResizeWindowRequest {
  label : String
  width : Int
  height : Int
} derive(ToJson, FromJson)

///|
/// Toggle a target window's fullscreen state.
pub struct FullscreenWindowRequest {
  label : String
  fullscreen : Bool
} derive(ToJson, FromJson)

///|
pub extend WindowInfo with ToJson::{to_json}

///|
pub extend WindowInfo with @json.FromJson::{from_json}

///|
pub extend LabelRequest with ToJson::{to_json}

///|
pub extend LabelRequest with @json.FromJson::{from_json}

///|
pub extend MoveWindowRequest with ToJson::{to_json}

///|
pub extend MoveWindowRequest with @json.FromJson::{from_json}

///|
pub extend ResizeWindowRequest with ToJson::{to_json}

///|
pub extend ResizeWindowRequest with @json.FromJson::{from_json}

///|
pub extend FullscreenWindowRequest with ToJson::{to_json}

///|
pub extend FullscreenWindowRequest with @json.FromJson::{from_json}

///|
/// Shared, mutable registry owned by the main process.
///
/// `ids` maps label -> window-id (== spawn base); `pids` maps label -> child
/// pid once spawned; `children` lists every live child so the serving loop can
/// wait on them.
pub struct WindowRegistry {
  ids : Map[String, Int]
  pids : Map[String, Int]
  children : Array[Int]
}

///|
/// Builds a window registry for the given configs. Window ids are assigned in
/// declaration order, matching the base each child uses when creating its own
/// window (see `assign_window_ids` in `lepus.mbt`).
pub fn WindowRegistry::new(configs : Array[WindowConfig]) -> WindowRegistry {
  { ids: assign_window_ids(configs), pids: Map([]), children: [], }
}

///|
/// Constructs the `windows` plugin. `argv0` is the executable path used to
/// spawn lazy child windows; `wm` must be the main-process `WindowManager`.
pub fn WindowRegistry::plugin(
  self : WindowRegistry,
  wm : @webview.WindowManager,
  argv0 : String,
) -> @webview.Plugin {
  @webview.Plugin("windows", plugin => {
    plugin.command_sync("list", fn(_ : Json) -> Array[WindowInfo] {
      let out : Array[WindowInfo] = []
      self.ids.each(fn(label, _id) {
        out.push({ label, open: self.is_open(label), })
      })
      out
    })
    plugin.command_sync("open", fn(req : LabelRequest) -> Bool {
      self.open(wm, argv0, req.label)
    })
    plugin.command_sync("close", fn(req : LabelRequest) -> Bool {
      self.with_window(req.label, fn(id) {
        ignore(wm.close_window(id))
        true
      })
    })
    plugin.command_sync("show", fn(req : LabelRequest) -> Bool {
      self.with_window(req.label, fn(id) { wm.set_visibility(id, true) == 0 })
    })
    plugin.command_sync("hide", fn(req : LabelRequest) -> Bool {
      self.with_window(req.label, fn(id) { wm.set_visibility(id, false) == 0 })
    })
    plugin.command_sync("move", fn(req : MoveWindowRequest) -> Bool {
      self.with_window(req.label, fn(id) {
        wm.set_position(id, req.x, req.y) == 0
      })
    })
    plugin.command_sync("resize", fn(req : ResizeWindowRequest) -> Bool {
      self.with_window(req.label, fn(id) {
        wm.set_size(id, req.width, req.height, None) == 0
      })
    })
    plugin.command_sync("minimize", fn(req : LabelRequest) -> Bool {
      self.with_window(req.label, fn(id) { wm.minimize_window(id) == 0 })
    })
    plugin.command_sync("maximize", fn(req : LabelRequest) -> Bool {
      self.with_window(req.label, fn(id) { wm.maximize_window(id) == 0 })
    })
    plugin.command_sync("set_fullscreen", fn(
      req : FullscreenWindowRequest,
    ) -> Bool {
      self.with_window(req.label, fn(id) {
        wm.set_fullscreen_window(id, req.fullscreen) == 0
      })
    })
  })
}

///|
fn WindowRegistry::is_open(self : WindowRegistry, label : String) -> Bool {
  match self.pids.get(label) {
    Some(pid) => pid > 0
    None => false
  }
}

///|
/// Opens (spawns if needed) a window by label and ensures it is visible.
fn WindowRegistry::open(
  self : WindowRegistry,
  wm : @webview.WindowManager,
  argv0 : String,
  label : String,
) -> Bool {
  let id = match self.ids.get(label) {
    Some(id) => id
    None => return false
  }
  // Already spawned: just reveal it.
  if self.is_open(label) {
    return wm.set_visibility(id, true) == 0
  }
  let pid = wm.spawn_process(argv0, @webview.child_arg_for(id, label))
  guard pid > 0 else { return false }
  self.pids.set(label, pid)
  self.children.push(pid)
  true
}

///|
/// Runs `action` with the window id for `label` when it is currently spawned.
fn WindowRegistry::with_window(
  self : WindowRegistry,
  label : String,
  action : (Int) -> Bool,
) -> Bool {
  let id = match self.ids.get(label) {
    Some(id) => id
    None => return false
  }
  guard self.is_open(label) else { return false }
  action(id)
}

///|
/// Returns the live child pids (used by the serving loop to know when to stop
/// and to pick up lazily-spawned windows).
fn WindowRegistry::live_children(self : WindowRegistry) -> Array[Int] {
  self.children
}

///|
/// A multi-window app with runtime window management (see `Windows::run`).
pub struct Windows {
  configs : Array[WindowConfig]
  plugins : Array[@webview.Plugin]
}

///|
/// Builds a window-managed app.
pub fn Windows::new(
  configs : Array[WindowConfig],
  plugins? : Array[@webview.Plugin] = [],
) -> Windows {
  { configs, plugins, }
}

///|
/// Runs a window-managed app end-to-end.
///
/// The main process spawns non-hidden windows up front, installs the
/// label-addressed `windows` plugin plus the cross-window event bus, and serves
/// commands from every child. Hidden windows are spawned lazily by `open`.
pub async fn Windows::run(self : Windows) -> Unit {
  assert_unique_labels(self.configs)
  match @webview.detect_child_window() {
    Some((base, label)) => {
      let bus = EventBus::new(Map([]))
      let wm = @webview.WindowManager::init(is_main=false)
      let registry = WindowRegistry::new(self.configs)
      let all_plugins = self.plugins + [bus.plugin(wm), registry.plugin(wm, "")]
      let config = find_window_config(self.configs, label)
      let window = build_runtime_window(config, all_plugins)
      window.run_child(base)
    }
    None => {
      let args = @env.args()
      guard args.length() > 0 else { abort("Windows::run: missing argv[0]") }
      let argv0 = args[0]
      let wm = @webview.WindowManager::init(is_main=true)
      let registry = WindowRegistry::new(self.configs)
      // Spawn non-hidden windows immediately.
      for config in self.configs {
        if !config.hidden {
          let opened = registry.open(wm, argv0, config.label())
          guard opened else {
            abort("Windows::run: spawn child for " + config.label() + " failed")
          }
        }
      }
      let bus = EventBus::new(assign_window_ids(self.configs))
      let all_plugins = self.plugins +
        [bus.plugin(wm), registry.plugin(wm, argv0)]
      let router = @webview.build_router(all_plugins)
      router.serve_many_dynamic(wm, fn() { registry.live_children() })
    }
  }
}
