# Architecture

Lepus has three layers: the application API, the WebView runtime, and native
FFI implementations.

```text
MoonBit application
  └─ lepus-apps/lepus
       ├─ Window / WindowConfig / App
       ├─ source resolution
       ├─ windows + events built-ins
       └─ official plugins
            └─ lepus-apps/lepus/webview
                 ├─ WebView and managed Window
                 ├─ PluginHost / PluginBuilder
                 ├─ process command router/proxy
                 └─ WindowManager IPC
                      └─ C/native WebView and window-manager bindings
```

## Application layer

The root package is responsible for resolving `Source` values, applying only
explicitly configured native options, installing plugins, validating labels,
and selecting a run model.

## WebView layer

`webview` owns native window lifecycle and injects two JavaScript surfaces:

- `window.LepusWindow` for operations on the current window.
- `window.lepusApi` for typed plugin commands.

A `Plugin` contributes JavaScript installation scripts and command handlers.
Payloads cross the bridge as JSON and are decoded into MoonBit types.

## Plugin command flow

```text
JavaScript Promise
  → injected plugin API
  → command bridge
  → PluginHost / ProcessCommandRouter
  → MoonBit handler
  → JSON response or error
  → Promise resolve/reject
```

In single-process applications the plugin handler is installed directly in the
window host. In process-per-window applications child windows proxy commands to
the parent process when a plugin has a parent-side handler.

## Multi-window flow

`App::run_single_process` creates every WebView in one task group and runs one
native event loop. `App::run` assigns deterministic IDs from declaration order,
starts a main command router, and spawns child processes for windows.

The built-in `windows` plugin maps stable labels to native IDs. The built-in
`events` plugin delivers a `CustomEvent("lepus_event")` to a target window.

## Source flow

- URL sources navigate directly.
- Local sources register a generated custom protocol mapped to a directory.
- Memory sources materialize files for serving through a generated protocol.
- ZIP sources are decoded into a memory source before window creation.

## Public API levels

Use the highest layer that fits:

1. Root `Window` for a simple application.
2. Root `App` and `WindowConfig` for multi-window applications.
3. `webview.Window` and `Plugin` for custom runtime integration.
4. `WebView`, `WindowManager`, and FFI packages only for framework-level work.
