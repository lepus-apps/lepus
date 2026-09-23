///|
/// A plugin definition that can be installed into a `PluginHost`.
///
/// A plugin is typically exposed from a MoonBit module:
///
/// ```moonbit nocheck
/// pub fn plugin() -> @webview.Plugin {
///   @webview.Plugin::new("math", fn(plugin) {
///     plugin.command("sum", fn(payload : SumPayload) {
///       SumReply{ total: payload.left + payload.right }
///     })
///   })
/// }
/// ```
///
/// Managed plugins are built once and then used in both:
/// - parent process: register real handlers
/// - child process: register proxy handlers or direct handlers
pub struct Plugin {
  name : String
  install_scripts : Array[String]
  parent_installers : Array[(ProcessPluginRouter) -> Unit]
  child_installers : Array[(PluginContext[Unit], ProcessCommandProxy) -> Unit]
  direct_installers : Array[(PluginContext[Unit]) -> Unit]
}

///|
/// Registration context used while building a managed `Plugin`.
pub struct PluginBuilder {
  plugin_name : String
  install_scripts : Array[String]
  parent_installers : Array[(ProcessPluginRouter) -> Unit]
  child_installers : Array[(PluginContext[Unit], ProcessCommandProxy) -> Unit]
  direct_installers : Array[(PluginContext[Unit]) -> Unit]
}

///|
/// Plugin host built on top of `CommandBridge`.
///
/// On the JavaScript side this exposes:
/// - `window[global_name]["@@call"](plugin_name, api_name, ...args)`
/// - `window[global_name][plugin_name][api_name](...args)`
///
/// Argument packing rule:
/// - one argument: sent as-is
/// - two or more arguments: sent as an array
struct PluginHost[X] {
  webview : WebView[X]
  bridge : CommandBridge[X]
  global_name : String
  plugins : Map[String, Bool]
  apis : Map[String, Bool]
}

///|
/// Registration context handed to a plugin while it installs its public APIs.
struct PluginContext[X] {
  host : PluginHost[X]
  plugin_name : String
}

///|
/// Creates a managed plugin whose commands are available from JavaScript
/// without exposing IPC details to user code.
pub fn Plugin::new(name : String, register : (PluginBuilder) -> Unit) -> Plugin {
  let builder = PluginBuilder::{
    plugin_name: name,
    install_scripts: [],
    parent_installers: [],
    child_installers: [],
    direct_installers: [],
  }
  register(builder)
  {
    name,
    install_scripts: builder.install_scripts,
    parent_installers: builder.parent_installers,
    child_installers: builder.child_installers,
    direct_installers: builder.direct_installers,
  }
}

///|
/// Registers a JavaScript snippet injected when this plugin is installed.
pub fn PluginBuilder::script(self : PluginBuilder, script : String) -> Unit {
  self.install_scripts.push(script)
}

///|
/// Registers a typed async plugin command.
pub fn[Payload : @json.FromJson + ToJson, Reply : @json.FromJson + ToJson] PluginBuilder::command(
  self : PluginBuilder,
  api_name : String,
  callback : async (Payload) -> Reply,
) -> Unit {
  let plugin_name = self.plugin_name
  self.parent_installers.push(router => router.command_async(api_name, callback))
  self.child_installers.push((plugin, proxy) => {
    let handler : (Payload) -> Reply raise = proxy.plugin_handler(
      plugin_name, api_name,
    )
    plugin.command_result_bg(api_name, handler)
  })
  self.direct_installers.push(plugin => plugin.command_async(api_name, callback))
}

///|
/// Registers a typed synchronous plugin command.
pub fn[Payload : @json.FromJson + ToJson, Reply : @json.FromJson + ToJson] PluginBuilder::command_sync(
  self : PluginBuilder,
  api_name : String,
  callback : (Payload) -> Reply,
) -> Unit {
  let plugin_name = self.plugin_name
  self.parent_installers.push(router => router.command(api_name, callback))
  self.child_installers.push((plugin, proxy) => {
    let handler : (Payload) -> Reply raise = proxy.plugin_handler(
      plugin_name, api_name,
    )
    plugin.command_result_bg(api_name, handler)
  })
  self.direct_installers.push(plugin => plugin.command_sync(api_name, callback))
}

///|
/// Registers a typed async plugin command that can raise explicit command
/// errors.
pub fn[Payload : @json.FromJson + ToJson, Reply : @json.FromJson + ToJson] PluginBuilder::command_result_async(
  self : PluginBuilder,
  api_name : String,
  callback : async (Payload) -> Reply raise Error,
) -> Unit {
  let plugin_name = self.plugin_name
  self.parent_installers.push(router => {
    router.command_result_async(api_name, callback)
  })
  self.child_installers.push((plugin, proxy) => {
    let handler : (Payload) -> Reply raise = proxy.plugin_handler(
      plugin_name, api_name,
    )
    plugin.command_result_bg(api_name, handler)
  })
  self.direct_installers.push(plugin => {
    plugin.command_result_async(api_name, callback)
  })
}

///|
/// Creates a plugin host backed by a `CommandBridge`.
///
/// `global_name` controls the JavaScript namespace used for plugin APIs
/// (defaults to `window.lepusApi`).
pub fn[X] PluginHost::new(
  webview : WebView[X],
  global_name? : String = "lepusApi",
) -> PluginHost[X] {
  let bridge = CommandBridge::new(webview, global_name="lepusBridge")
  let host = PluginHost::{ webview, bridge, global_name, plugins: {}, apis: {} }
  host.install_script(make_plugin_host_script(global_name, "lepusBridge"))
  host
}

///|
/// Installs a plugin into the host.
///
/// This aborts if another plugin with the same name has already been
/// installed on this host.
pub fn PluginHost::install(
  self : PluginHost[Unit],
  plugin : Plugin,
  proxy? : ProcessCommandProxy? = None,
) -> Unit {
  guard !is_disallowed_js_property_name(plugin.name) else {
    abort("PluginHost::install: reserved plugin name: " + plugin.name)
  }
  guard self.plugins.get(plugin.name) is None else {
    abort("PluginHost::install: plugin already installed: " + plugin.name)
  }
  let context = PluginContext::{ host: self, plugin_name: plugin.name }
  self.plugins.set(plugin.name, true)
  self.install_script(
    make_plugin_namespace_script(self.global_name, plugin.name),
  )
  for script in plugin.install_scripts {
    self.install_script(script)
  }
  match proxy {
    Some(proxy) =>
      for install in plugin.child_installers {
        install(context, proxy)
      }
    None =>
      for install in plugin.direct_installers {
        install(context)
      }
  }
}

///|
/// Destroys the plugin host and all installed plugins.
pub fn[X] PluginHost::destroy(self : PluginHost[X]) -> Unit {
  self.plugins.clear()
  self.apis.clear()
  self.bridge.destroy()
}

///|
/// Returns the JavaScript global object name used for plugin APIs.
pub fn[X] PluginHost::global_name(self : PluginHost[X]) -> String {
  self.global_name
}

///|
/// Returns the underlying command bridge used by the plugin host.
pub fn[X] PluginHost::command_bridge(self : PluginHost[X]) -> CommandBridge[X] {
  self.bridge
}

///|
/// Returns the plugin name currently being installed.
pub fn[X] PluginContext::name(self : PluginContext[X]) -> String {
  self.plugin_name
}

///|
/// Registers a typed plugin command that performs blocking work on a detached
/// native thread and responds asynchronously to JavaScript.
pub fn[X, Payload : @json.FromJson, Reply : ToJson] PluginContext::command_result_bg(
  self : PluginContext[X],
  api_name : String,
  callback : (Payload) -> Reply raise,
) -> Unit {
  self.install_command_api(api_name, command_name => {
    self.host.bridge.handle_result_bg(command_name, callback)
  })
}

///|
/// Registers a typed synchronous plugin command.
pub fn[X, Payload : @json.FromJson, Reply : ToJson] PluginContext::command_sync(
  self : PluginContext[X],
  api_name : String,
  callback : (Payload) -> Reply,
) -> Unit {
  self.install_command_api(api_name, command_name => {
    self.host.bridge.handle_sync(command_name, callback)
  })
}

///|
/// Registers an async typed plugin command.
///
/// The command becomes callable from JavaScript through:
/// `window.lepusApi[plugin_name][api_name](...args)`.
/// The callback is spawned as a background task, non-blocking.
pub fn[X, Payload : @json.FromJson, Reply : ToJson] PluginContext::command_async(
  self : PluginContext[X],
  api_name : String,
  callback : async (Payload) -> Reply,
) -> Unit {
  self.install_command_api(api_name, command_name => {
    self.host.bridge.handle_async(command_name, callback)
  })
}

///|
/// Registers an async typed plugin command that can return explicit command errors.
pub fn[X, Payload : @json.FromJson, Reply : ToJson] PluginContext::command_result_async(
  self : PluginContext[X],
  api_name : String,
  callback : async (Payload) -> Reply raise Error,
) -> Unit {
  self.install_command_api(api_name, command_name => {
    self.host.bridge.handle_result_async(command_name, callback)
  })
}

///|
pub fn[X] PluginContext::register_api(
  self : PluginContext[X],
  api_name : String,
) -> String {
  guard !is_disallowed_js_property_name(api_name) else {
    abort(
      "PluginContext::register_api: reserved API name: " +
      self.plugin_name +
      "." +
      api_name,
    )
  }
  let command_name = plugin_command_name(self.plugin_name, api_name)
  guard self.host.apis.get(command_name) is None else {
    abort(
      "PluginContext::register_api: API already registered: " +
      self.plugin_name +
      "." +
      api_name,
    )
  }
  self.host.apis.set(command_name, true)
  command_name
}

///|
pub fn[X] PluginContext::install_command_api(
  self : PluginContext[X],
  api_name : String,
  register : (String) -> Unit,
) -> Unit {
  let command_name = self.register_api(api_name)
  log(1, "[plugin] registering command: \{command_name}")
  register(command_name)
  self.host.install_script(
    make_plugin_api_script(
      self.host.global_name,
      self.plugin_name,
      api_name,
      command_name,
    ),
  )
}

///|
pub fn[X] PluginHost::install_script(
  self : PluginHost[X],
  script : String,
) -> Unit {
  self.webview.init(script)
  self.webview.eval(script)
}

///|
fn string_literal(value : String) -> String {
  Json::string(value).stringify()
}

///|
fn plugin_command_name(plugin_name : String, api_name : String) -> String {
  "plugin:\{string_literal(plugin_name)}:\{string_literal(api_name)}"
}

///|
fn is_disallowed_js_property_name(name : String) -> Bool {
  name is (['@', '@', ..] | "__proto__" | "prototype" | "constructor")
}

///|
fn make_plugin_host_script(
  global_name : String,
  bridge_global_name : String,
) -> String {
  let global_name_js = string_literal(global_name)
  let bridge_global_name_js = string_literal(bridge_global_name)
  (
    $|!function(){const n=\{global_name_js},e=window[n],t=e&&"object"==typeof e?e:Object.create(null);function r(){const n=window[\{bridge_global_name_js}];return n&&"function"==typeof n.send?n:null}function o(n,e){return n<2?e:2===n?e[1]:Array.prototype.slice.call(e,1)}t["@@bridgeGlobal"]=\{bridge_global_name_js},t["@@call"]=function(n,e){const t=r(),i=o(arguments.length,arguments);return t?t.send("plugin:"+JSON.stringify(n)+":"+JSON.stringify(e),i):Promise.reject(new Error("MoonBit command bridge is not available"))},t["@@ensurePlugin"]=function(n){const e=t[n];if(e&&"object"==typeof e)return e;const o=Object.create(null);return t[n]=o,o},t["@@defineApi"]=function(n,e,o){const i=t["@@ensurePlugin"](n);return i[e]=function(){const n=r(),e=arguments.length<2?arguments[0]:Array.prototype.slice.call(arguments);return n?n.send(o,e):Promise.reject(new Error("MoonBit command bridge is not available"))},i[e]},t["@@has"]=function(n,e){const o=t[n];return!(!o||"function"!=typeof o[e])},window[n]=t}();
  )
}

///|
fn make_plugin_namespace_script(
  global_name : String,
  plugin_name : String,
) -> String {
  let global_name_js = string_literal(global_name)
  let plugin_name_js = string_literal(plugin_name)
  (
    $|!function(){const e=\{global_name_js},n=\{plugin_name_js},o=window[e]&&"object"==typeof window[e]?window[e]:window[e]=Object.create(null);"function"!=typeof o["@@ensurePlugin"]?o[n]&&"object"==typeof o[n]||(o[n]=Object.create(null)):o["@@ensurePlugin"](n)}();
  )
}

///|
fn make_plugin_api_script(
  global_name : String,
  plugin_name : String,
  api_name : String,
  command_name : String,
) -> String {
  let global_name_js = string_literal(global_name)
  let plugin_name_js = string_literal(plugin_name)
  let api_name_js = string_literal(api_name)
  let command_name_js = string_literal(command_name)
  (
    $|!function(){const g=\{global_name_js},p=\{plugin_name_js},a=\{api_name_js},c=\{command_name_js},h=window[g]&&"object"==typeof window[g]?window[g]:window[g]=Object.create(null);if("function"==typeof h["@@defineApi"])return void h["@@defineApi"](p,a,c);(h[p]&&"object"==typeof h[p]?h[p]:h[p]=Object.create(null))[a]=function(){const p=arguments.length<2?arguments[0]:Array.prototype.slice.call(arguments),a=h["@@bridgeGlobal"],g=a&&window[a];return g&&"function"==typeof g.send?g.send(c,p):Promise.reject(new Error("MoonBit command bridge is not available"))}}();
  )
}

///|
test "reserved plugin and api names share JS property guard" {
  assert_true(is_disallowed_js_property_name("@@call"))
  assert_true(is_disallowed_js_property_name("__proto__"))
  assert_true(is_disallowed_js_property_name("constructor"))
  assert_false(is_disallowed_js_property_name("math"))
  assert_false(is_disallowed_js_property_name("sum"))
}

///|
test "plugin command names remain JSON quoted for stable JS dispatch" {
  assert_eq(plugin_command_name("math", "sum"), "plugin:\"math\":\"sum\"")
  assert_eq(plugin_command_name("a:b", "c"), "plugin:\"a:b\":\"c\"")
  assert_eq(
    plugin_command_name("quote\"plugin", "slash\\api"),
    "plugin:\"quote\\\"plugin\":\"slash\\\\api\"",
  )
}
