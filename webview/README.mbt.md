# Lepus WebView

Package `lepus-apps/lepus/webview` is the low-level native window, JavaScript
bridge, plugin, and inter-process communication runtime used by the root Lepus
API. Application code should normally use `lepus-apps/lepus` instead.

## Runtime layers

```text
WebView / Window
  ├─ native window lifecycle and navigation
  ├─ window.LepusWindow JavaScript facade
  └─ PluginHost
       ├─ window.lepusApi command installation
       ├─ ProcessCommandRouter
       └─ ProcessCommandProxy / WindowManager IPC
```

## Managed `Window`

`Window(...)` configures a low-level managed window. The old `Window::new`
alias is deprecated.

```moonbit nocheck
///|
async fn main {
  let window = @webview.Window(
    label="main",
    title="Lepus WebView",
    width=960,
    height=640,
  )
  window.set_html("<html><body><h1>Hello</h1></body></html>")
  window.run()
}
```

### Content and lifecycle

- `set_html`, `navigate`, `set_custom_protocol`
- `run`, `run_child`, `run_many`
- `show`, `hide`, `focus`, `close`
- `install(plugin)`

### Window operations

- `set_size`, `set_position`, `set_fullscreen`
- `minimize`, `maximize`, `unmaximize`, `toggle_maximize`
- `toggle_fullscreen`, `start_drag`
- `set_window_customization`, `set_traffic_light_position`
- `eval`

## Raw `WebView`

`WebView::new_managed(task_group, ...)` creates a task-group-owned native
WebView. It provides direct access to navigation, sizing, title, developer
tools, custom protocols, JavaScript evaluation, handles, and destruction.

Use this type only when implementing custom runtime integration. The root
package and managed `Window` handle plugin installation and source setup for
normal applications.

## Window options

`WindowOptions` contains optional native flags:

- decorations, resizable, closeable, minimizable, maximizable
- always-on-top, always-on-bottom
- transparent, shadow, skip-taskbar, visible-on-all-workspaces
- title-bar style, title-bar overlay, hidden title

Methods:

- `default()` returns all options unset.
- `is_empty()` reports whether no native override is requested.
- `merge(other)` combines option sets.
- `wants_custom_titlebar()` and `wants_transparency()` report support-layer needs.
- `wm_mask()` returns the native option bit mask.

`TitleBarStyle` variants are `Visible`, `Transparent`, and `Overlay`.

## Plugins

Create a plugin with `Plugin(name, configure)`. The old `Plugin::new` alias is
deprecated.

```moonbit nocheck
///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin("math", builder => {
    builder.command_sync("double", fn(value : Int) -> Int { value * 2 })
    builder.script("window.mathPluginInstalled = true;")
  })
}
```

`PluginBuilder` handlers:

- `command_sync`: synchronous non-raising handler.
- `command`: asynchronous handler.
- `command_result_async`: asynchronous result-aware handler.
- `script`: install JavaScript before exposing commands.

`PluginHost` attaches plugins to a WebView. `install`, `install_script`,
`command_bridge`, `global_name`, and `destroy` are framework integration APIs.
The default global name is used to create `window.lepusApi`.

## Process commands

`ProcessCommandRequest` contains a command name and JSON payload.
`ProcessCommandResponse` is `Ok(Json)` or `Error(String)` and can be serialized
for IPC.

`ProcessCommandRouter` registers typed handlers:

- `handle`, `handle_async`
- `handle_result`, `handle_result_async`
- `plugin(name, configure)` for namespaced plugin handlers
- `dispatch`, `serve`, `serve_many`, `serve_many_dynamic`

`ProcessCommandProxy` sends typed requests through a `WindowManager` and decodes
the reply. `call_plugin` targets `<plugin>.<command>` and accepts optional target
window and timeout values.

## Window manager

`WindowManager` is the native multi-process/window control API. It supports:

- initialization and process-role checks
- create, run, destroy, show/hide, focus, move, resize, and state changes
- process fork/spawn/connect/wait
- directed messages, broadcasts, requests, and responses
- process-command serving

Return values from native operations are integer status codes; `0` conventionally
means success. Prefer the root package's label-based `windows` API unless native
IDs and explicit process control are required.

## JavaScript surfaces

- `window.LepusWindow`: current-window controls.
- `window.lepusApi.<plugin>.<command>(payload)`: promise-based plugin calls.

Command payloads and replies are JSON. Decode or handler failures become command
errors and reject the JavaScript promise.

## Custom title bars

Custom title-bar helpers are enabled when requested by window options. Mark
regions with:

- `.lepus-drag` or `[data-lepus-drag="true"]` for draggable areas.
- `.lepus-no-drag` for buttons, inputs, and other interactive descendants.

Equivalent CSS:

```css
.titlebar { -webkit-app-region: drag; }
.titlebar button { -webkit-app-region: no-drag; }
```

## Build and test

```sh
moon check --target native
moon test --target native -p lepus-apps/lepus/webview
moon info && moon fmt
```

## License

Apache-2.0
