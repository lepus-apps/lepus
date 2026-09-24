///|
pub enum TitleBarStyle {
  Default = 0
  Hidden = 1
} derive(Debug, Eq, ToJson, FromJson, Hash)

///|
pub struct MemoryFile {
  path : String
  content : Bytes
} derive(Debug, Eq, ToJson, FromJson, Hash)

///|
pub struct MemorySource {
  entry : String
  files : Array[MemoryFile]
} derive(Debug, Eq, ToJson, FromJson, Hash)

///|
pub(all) enum Source {
  Url(String)
  Local(String)
  Memory(MemorySource)
} derive(Debug, Eq, ToJson, FromJson, Hash)

///|
pub struct WindowConfig {
  label : String
  title : String
  width : Int
  height : Int
  debug : Int
  devtools : Bool
  frameless : Bool
  resizable : Bool
  always_on_top : Bool
  transparent : Bool
  title_bar_style : TitleBarStyle
  title_bar_overlay : Bool
  traffic_light_position : (Int, Int)
  source : Source?
} derive(Debug, Eq, ToJson, FromJson, Hash)

///|
priv struct ResolvedSource {
  url : String
  custom_protocols : Array[(String, String)]
}

///|
pub fn MemoryFile::from_bytes(path : String, content : Bytes) -> MemoryFile {
  { path, content, }
}

///|
pub fn MemoryFile::from_string(path : String, content : String) -> MemoryFile {
  let content = @utf8.encode(content)
  { path, content, }
}

///|
#alias(new, deprecated="Use `MemorySource()` instead")
pub fn MemorySource::MemorySource(
  files : Array[MemoryFile],
  entry? : String = "index.html",
) -> MemorySource {
  { entry, files, }
}

///|
pub fn Source::html(html : String) -> Source {
  Memory(MemorySource([MemoryFile::from_string("index.html", html)]))
}

///|
pub fn Source::zip(zip : Bytes) -> Source raise {
  let archive = @zipc.Archive::from_bytes(zip)
  let files = []
  archive.members.each((name, m) => {
    if m.kind is File(file) {
      files.push(MemoryFile::from_bytes(name, file.to_bytes()))
    }
  })
  Memory(MemorySource(files))
}

///|
pub fn WindowConfig::new(
  label? : String = "",
  title? : String = "Lepus App",
  width? : Int = 800,
  height? : Int = 600,
  debug? : Int = 0,
  devtools? : Bool = false,
  frameless? : Bool = false,
  resizable? : Bool = true,
  always_on_top? : Bool = false,
  transparent? : Bool = false,
  title_bar_style? : TitleBarStyle = Default,
  title_bar_overlay? : Bool = false,
  traffic_light_position? : (Int, Int) = (-1, -1),
  source? : Source,
) -> WindowConfig {
  {
    label,
    title,
    width,
    height,
    debug,
    devtools,
    frameless,
    resizable,
    always_on_top,
    transparent,
    title_bar_style,
    title_bar_overlay,
    traffic_light_position,
    source,
  }
}

///|
/// Returns the window label used for stable cross-window addressing.
/// Falls back to `title` when no explicit label was given.
pub fn WindowConfig::label(self : WindowConfig) -> String {
  if self.label.is_empty() {
    self.title
  } else {
    self.label
  }
}

///|
pub fn WindowConfig::set_source(
  self : WindowConfig,
  source : Source,
) -> WindowConfig {
  { ..self, source: Some(source), }
}

///|
pub fn WindowConfig::navigate(
  self : WindowConfig,
  url : String,
) -> WindowConfig {
  self.set_source(Url(url))
}

///|
pub struct App {
  windows : Array[WindowConfig]
  plugins : Array[@webview.Plugin]
}

///|
pub struct Window {
  config : WindowConfig
  plugins : Array[@webview.Plugin]
}

///|
#alias(new, deprecated="Use `Window()` instead")
pub fn Window::Window(
  label? : String = "",
  title? : String = "Lepus App",
  width? : Int = 800,
  height? : Int = 600,
  debug? : Int = 0,
  devtools? : Bool = false,
  frameless? : Bool = false,
  resizable? : Bool = true,
  always_on_top? : Bool = false,
  transparent? : Bool = false,
  title_bar_style? : TitleBarStyle = Default,
  title_bar_overlay? : Bool = false,
  traffic_light_position? : (Int, Int) = (-1, -1),
  source? : Source,
  plugins? : Array[@webview.Plugin] = [],
) -> Window {
  {
    config: {
      label,
      title,
      width,
      height,
      debug,
      devtools,
      frameless,
      resizable,
      always_on_top,
      transparent,
      title_bar_style,
      title_bar_overlay,
      traffic_light_position,
      source,
    },
    plugins,
  }
}

///|
pub fn Window::set_source(self : Window, source : Source) -> Window {
  { ..self, config: self.config.set_source(source), }
}

///|
pub fn Window::navigate(self : Window, url : String) -> Window {
  self.set_source(Url(url))
}

///|
pub async fn Window::run(self : Window) -> Unit {
  App::new([self.config], plugins=self.plugins).run()
}

///|
pub fn App::new(
  windows : Array[WindowConfig],
  plugins? : Array[@webview.Plugin] = [],
) -> App {
  { windows, plugins, }
}

///|
pub fn App::with_windows(
  windows : Array[WindowConfig],
  plugins? : Array[@webview.Plugin] = [],
) -> App {
  guard windows.length() > 0 else {
    abort("App::with_windows requires at least one window")
  }
  { windows, plugins, }
}

///|
pub fn App::add_window(self : App, config : WindowConfig) -> Unit {
  self.windows.push(config)
}

///|
pub fn App::window_count(self : App) -> Int {
  self.windows.length()
}

///|
pub async fn App::run(self : App, window_index? : Int) -> Unit {
  let selected = match window_index {
    Some(i) => {
      guard i >= 0 && i < self.windows.length() else {
        abort("App::run window_index out of range")
      }
      [self.windows[i]]
    }
    None => self.windows
  }
  guard selected.length() > 0 else {
    abort("App::run requires at least one window")
  }
  assert_unique_labels(selected)
  let bus = EventBus::new()
  let all_plugins = self.plugins + [bus.plugin()]
  match @webview.detect_child_window() {
    Some((base, label)) => {
      // 子进程：找到自己窗口的配置并运行
      let config = find_window_config(self.windows, label)
      let window = build_runtime_window(config, all_plugins)
      window.run_child(base)
    }
    None => {
      // 主进程：为每个窗口生成唯一的 label，spawn 子进程并统一服务
      let labels : Array[String] = []
      for config in selected {
        labels.push(config.label())
      }
      let router = @webview.build_router(all_plugins)
      @webview.Window::run_many(labels, router)
    }
  }
}

///|
/// Returns the window whose `label()` matches `label`, aborting when absent.
fn find_window_config(
  windows : Array[WindowConfig],
  label : String,
) -> WindowConfig {
  for config in windows {
    if config.label() == label {
      return config
    }
  }
  abort("App: no window with label " + label)
}

///|
/// Asserts that every window label is unique so cross-window addressing and
/// child-process dispatch are unambiguous.
fn assert_unique_labels(windows : Array[WindowConfig]) -> Unit {
  let seen : Array[String] = []
  for config in windows {
    let label = config.label()
    guard !seen.contains(label) else {
      abort("App: duplicate window label " + label)
    }
    seen.push(label)
  }
}

///|
/// Builds a runtime `@webview.Window` from a `WindowConfig`, resolving its
/// source, registering custom protocols, and installing the App-level plugins.
async fn build_runtime_window(
  config : WindowConfig,
  plugins : Array[@webview.Plugin],
) -> @webview.Window {
  let window = @webview.Window(
    label=config.label(),
    title=config.title,
    width=config.width,
    height=config.height,
    debug=config.debug,
    devtools=config.devtools,
    frameless=config.frameless,
    resizable=config.resizable,
    always_on_top=config.always_on_top,
    transparent=config.transparent,
    title_bar_style=match config.title_bar_style {
      Default => Default
      Hidden => Hidden
    },
    title_bar_overlay=config.title_bar_overlay,
    traffic_light_position=config.traffic_light_position,
  )
  guard config.source is Some(source) else {
    abort("WindowConfig::source is required")
  }
  let resolved = resolve_source(source)
  resolved.custom_protocols.each(mapping => {
    let (scheme, root_dir) = mapping
    window.set_custom_protocol(scheme, root_dir)
  })
  window.navigate(resolved.url)
  plugins.each(plugin => window.install(plugin))
  window
}

///|
async fn resolve_source(source : Source) -> ResolvedSource {
  match source {
    Url(url) => { url, custom_protocols: [], }
    Local(path) => resolve_local_fs(path)
    Memory(source) => resolve_memory_source(source)
  }
}

///|
async fn resolve_local_fs(path : String) -> ResolvedSource {
  let fs_path = if path.has_prefix("file://") {
    file_url_to_path(path)
  } else {
    path
  }
  let normalized = fs_path.replace_all(old="\\", new="/")
  let entry_path = if is_html_path(normalized) {
    normalized
  } else {
    join_path(normalized, "index.html")
  }
  guard @fs.exists(entry_path) else {
    abort("LocalFs source does not exist: " + entry_path)
  }
  guard @fs.kind(entry_path) == Regular else {
    abort("LocalFs source is not a regular file: " + entry_path)
  }
  guard @fs.can_read(entry_path) else {
    abort("LocalFs source is not readable: " + entry_path)
  }
  { url: to_file_url(@fs.realpath(entry_path)), custom_protocols: [], }
}

///|
async fn resolve_memory_source(source : MemorySource) -> ResolvedSource {
  guard source.files.length() > 0 else {
    abort("MemoryFs source requires at least one file")
  }
  let entry = sanitize_memory_relative_path(source.entry)
  let root = @fs.realpath(@fs.tmpdir(prefix="lepus-source"))
  let mut has_entry = false
  for file in source.files {
    let relative_path = sanitize_memory_relative_path(file.path)
    if relative_path == entry {
      has_entry = true
    }
    let file_path = join_path(root, relative_path)
    match parent_dir(file_path) {
      Some(parent) =>
        if !@fs.exists(parent) {
          @fs.mkdir(parent, permission=0o700, recursive=true)
        }
      None => ()
    }
    @fs.write_file(
      file_path,
      file.content,
      create_mode=CreateOrTruncate,
      permission=0o644,
    )
  }
  guard has_entry else { abort("MemoryFs entry file not found: " + entry) }
  {
    url: memory_source_entry_url(entry),
    custom_protocols: [(memory_source_mapping_name(), root)],
  }
}

///|
#cfg(platform="windows")
fn memory_source_mapping_name() -> String {
  "lepus"
}

///|
#cfg(not(platform="windows"))
fn memory_source_mapping_name() -> String {
  "lepus"
}

///|
#cfg(platform="windows")
fn memory_source_entry_url(entry : String) -> String {
  "http://lepus/" + entry
}

///|
#cfg(not(platform="windows"))
fn memory_source_entry_url(entry : String) -> String {
  "lepus://localhost/" + entry
}

///|
fn to_file_url(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  if normalized.has_prefix("/") {
    "file://" + normalized
  } else {
    "file:///" + normalized
  }
}

///|
fn join_path(base : String, leaf : String) -> String {
  let base = base.trim_end(chars="/\\").to_owned()
  let leaf = leaf.trim_start(chars="/\\").to_owned()
  if base.is_empty() {
    leaf
  } else if leaf.is_empty() {
    base
  } else {
    base + "/" + leaf
  }
}

///|
fn is_html_path(path : String) -> Bool {
  path.has_suffix(".html") ||
  path.has_suffix(".htm") ||
  path.has_suffix(".xhtml")
}

///|
fn file_url_to_path(url : String) -> String {
  guard url.has_prefix("file://") else { url }
  let path = url[7:].to_owned()
  if path.is_empty() {
    "/"
  } else {
    path
  }
}

///|
fn sanitize_memory_relative_path(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  let trimmed = normalized.trim_start(chars="/").trim_end(chars="/").to_owned()
  guard !trimmed.is_empty() else { abort("MemoryFs path cannot be empty") }
  guard trimmed != ".." &&
    !trimmed.has_prefix("../") &&
    !trimmed.has_suffix("/..") &&
    !trimmed.contains("/../") &&
    trimmed != "." &&
    !trimmed.has_prefix("./") &&
    !trimmed.has_suffix("/.") &&
    !trimmed.contains("/./") else {
    abort("MemoryFs path cannot use '.' or '..': " + path)
  }
  trimmed
}

///|
fn parent_dir(path : String) -> String? {
  let path = path.trim_end(chars="/\\").to_owned()
  guard !path.is_empty() else { None }
  match path.rev_find("/") {
    Some(index) => {
      let parent = path[:index].trim_end(chars="/\\").to_owned()
      if parent.is_empty() {
        None
      } else {
        Some(parent)
      }
    }
    None =>
      match path.rev_find("\\") {
        Some(index) => {
          let parent = path[:index].trim_end(chars="/\\").to_owned()
          if parent.is_empty() {
            None
          } else {
            Some(parent)
          }
        }
        None => None
      }
  }
}
