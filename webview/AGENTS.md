# AGENTS.md — Repository Guide for Contributors & AI Agents

This document describes the structure, build/test workflow, coding conventions,
and architecture of **lepus-apps/lepus/webview** so that both human contributors and
AI coding agents can navigate and extend the project effectively.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Repository Structure](#repository-structure)
3. [Build & Test Commands](#build--test-commands)
4. [Architecture & Key Abstractions](#architecture--key-abstractions)
5. [Coding Style & Conventions](#coding-style--conventions)
6. [FFI & C Stub Layer](#ffi--c-stub-layer)
7. [JavaScript Bridge Protocol](#javascript-bridge-protocol)
8. [Platform Notes](#platform-notes)

---

## Project Overview

**lepus-apps/lepus/webview** is a modern desktop-application framework for
[MoonBit](https://www.moonbitlang.com/) based on native web technologies.  
It wraps the [webview](https://github.com/webview/webview) C library and exposes
a high-level MoonBit API that enables:

- Creating native desktop windows backed by a web-rendering engine (WebKit /
  WebView2).
- Bidirectional communication between MoonBit code and the embedded web page
  through a typed JSON command bridge.
- A plugin system that lets independent modules register named command handlers
  and emit events to JavaScript.

**Language:** MoonBit (native target only)  
**License:** Apache-2.0  
**Package name:** `lepus-apps/lepus/webview`

---

## Repository Structure

```
lepus/webview/
├── binding.mbt          # Remaining FFI decls that depend on webview enums (wm_set_size, wm_set_window_customization)
├── command.mbt          # CommandBridge & Command/CommandResponse types
├── plugin.mbt           # Plugin / PluginHost / PluginContext higher-level API
├── webview.mbt          # Public WebView struct and all its methods
├── moon.pkg             # Package config: link flags, native-stub (vendor cc), target filters
├── pkg.generated.mbti   # Auto-generated interface file (do not edit manually)
├── ffi/                 # Split native FFI packages (see "FFI & C Stub Layer")
│   ├── common/c_abi.h           # Shared platform preamble: pthread/socket shims, webview.h decls
│   ├── webview_sys/             # Raw webview.h bindings (bind/unbind, threads, cstr copy)
│   │   ├── binding.mbt
│   │   ├── moon.pkg
│   │   └── stub.c
│   └── window_manager/          # g_wm runtime: IPC transport, window lifecycle, platform view control
│       ├── binding.mbt          # wm_* extern decls (co-located with their C implementations)
│       ├── moon.pkg
│       └── stub.c
├── lib/                 # Pre-built webview shared libraries
│   ├── libwebview.dylib          (macOS symlink)
│   ├── libwebview.0.12.dylib
│   ├── libwebview.0.12.0.dylib
│   ├── webview.dll               (Windows)
│   └── webview.lib               (Windows import lib)
└── example/
    ├── main.mbt         # Runnable demo: plugin system + HTML UI
    └── moon.pkg         # Example package config (is_main = true)
```

### File Roles at a Glance

| File | Responsibility |
|------|---------------|
| `webview.mbt` | `WebView` struct, window lifecycle, JS eval/init, bind/unbind |
| `binding.mbt` | Remaining `extern "C"` decls tied to webview enums (`wm_set_size`, `wm_set_window_customization`) |
| `command.mbt` | `CommandBridge`, `Command`, `CommandResponse` — typed JSON RPC layer |
| `plugin.mbt` | `Plugin`, `PluginHost`, `PluginContext` — named plugin registry |
| `ffi/webview_sys/stub.c` | Raw webview.h glue: `moonbit_webview_bind/unbind`, background thread, cstr copy |
| `ffi/window_manager/stub.c` | Window-manager runtime: `g_wm` state, IPC transport, platform view control |

---

## Build & Test Commands

All commands use the [Moon](https://www.moonbitlang.com/docs/build-system/) build
tool.  The project targets **native** only (`supported_targets = "+native"`).

### Build

```bash
# Build the library and example
moon build --target native

# Build only the library package
moon build --target native lepus-apps/lepus/webview
```

### Run the Example

```bash
moon run --target native example
```

### Test

```bash
# Run all tests (unit tests live inside plugin.mbt)
moon test --target native
```

### Check / Type-check

```bash
moon check
```

### Update the Generated Interface File

```bash
moon info
```

> **Note:** The shared libraries under `lib/` must be present and reachable at
> link time. The `moon.pkg` link flags embed `-Wl,-rpath,lib` so that the dylib
> is found at runtime relative to the working directory on macOS/Linux.

---

## Architecture & Key Abstractions

### Layer Diagram

```
JavaScript (browser page)
        │  window.lepusApi[plugin][api](payload)
        │  window.lepusBridge.send(name, payload)
        ▼
  CommandBridge  (command.mbt)
        │  webview.bind() / webview.init() / webview.eval()
        ▼
    WebView  (webview.mbt)
        │  extern "C" FFI
        ▼
   binding.mbt  ──►  ffi/window_manager/stub.c  ──►  ffi/webview_sys/stub.c  ──►  webview_vendor.cc (webview.h impl)
```

### `WebView` (`webview.mbt`)

The central struct.  Wraps `WebView_t` (opaque C pointer) and manages:

- `bindings : Map[String, BindingHandle]` — active JS→MoonBit bindings.
- `destroy_hooks : Map[String, () -> Unit]` — callbacks run on `destroy()`.

Key methods: `new`, `run`, `destroy`, `bind`, `unbind`, `dispatch`, `terminate`,
`set_title`, `set_size`, `set_html`, `navigate`, `eval`, `init`, `response`.

### `CommandBridge` (`command.mbt`)

A typed JSON RPC layer over `WebView.bind()`.  
Injects a JavaScript helper (`window[global_name]`) that exposes:

- `send(name, payload) → Promise<CommandResponse>` — JS→MoonBit call.
- `onCommand(listener)` — subscribe to MoonBit→JS fire-and-forget events.

MoonBit side: `handle(name, callback)`, `handle_result(name, callback)`,
`send(name, payload)`.

### `Plugin` / `PluginHost` / `PluginContext` (`plugin.mbt`)

Higher-level registry on top of `CommandBridge`.

- **`Plugin`**: value object holding `name`, `register`, `on_install`,
  `on_destroy` callbacks.
- **`PluginHost`**: owns a `CommandBridge` and a map of installed plugins.
  Injects `window.lepusApi` JavaScript runtime.
- **`PluginContext`**: handed to `register` so a plugin can call
  `context.command(api_name, handler)` and `context.emit(event_name, payload)`.

Convenience helpers on `WebView`: `install_plugin`, `plugin_host`, `emit_plugin`.

---

## Coding Style & Conventions

### General

- **Language:** MoonBit. All source files use the `.mbt` extension.
- **Doc comments:** Every public declaration starts with `///|` followed by a
  doc-comment block (`///`). Internal helpers also carry doc stubs to aid
  navigation.
- **Naming:** `UpperCamelCase` for types/enums; `snake_case` for functions,
  methods, and variables. Method names follow the `Type::method_name` pattern.
- **Visibility:** Use `pub` for the public API surface. Keep implementation
  helpers package-private (no `pub`).
- **Derive macros:** Prefer `derive(ToJson, FromJson, Show, Eq)` on data types
  rather than implementing these traits manually.

### Error Handling

- Use `abort(...)` for programmer errors (duplicate bindings, reserved names,
  broken invariants). These represent logic bugs, not runtime failures.
- Use `raise Error` / `catch` / `try?` for recoverable failures in command
  handlers.
- Return `CommandResponse::error(message)` to propagate failures to the JS
  caller rather than panicking.

### FFI Bindings (`binding.mbt` files)

- `extern "C"` declarations are co-located with the package that implements
  them: raw `webview.h` glue in `ffi/webview_sys/binding.mbt`, the `wm_*`
  window-manager surface in `ffi/window_manager/binding.mbt`. The remaining
  `webview/binding.mbt` only holds the two declarations that take webview enum
  types (`wm_set_size`, `wm_set_window_customization`).
- Every `extern "C"` function maps directly to a webview C API symbol or a
  `moonbit_*` helper defined in the corresponding package's `stub.c`.
- Use `#borrow(param)` for `Bytes` parameters that should not transfer
  ownership to C.
- Use `#owned(param)` for closures whose lifetime must be managed by the C side.
- Do not add business logic to `binding.mbt` files; keep them as thin FFI surfaces.

### JavaScript Glue

- All injected scripts are built with plain string concatenation (no template
  engine dependency). Keep the minified form in `plugin.mbt` to reduce payload
  size, but document the logical structure in comments nearby.
- Script identifiers that cross the MoonBit/JS boundary (global object names,
  binding names, event names) are always JSON-quoted via
  `Json::string(value).stringify()` to prevent injection / name collisions.

### Tests

- Unit tests live in the same file as the code they test (inline `test` blocks).
- Test names describe the invariant being verified, not the function name.
- The test suite is intentionally minimal; prefer compile-time guarantees where
  possible.

---

## FFI & C Stub Layer

The original monolithic `webview/stub.c` (~3,500 lines) was split into small
FFI packages under `ffi/`, each with its own `moon.pkg` (`native-stub`) and a
thin `binding.mbt`. Both stubs share the platform preamble and `webview.h`
forward declarations via `ffi/common/c_abi.h` (a relative `#include`).

### `ffi/webview_sys/stub.c` (raw `webview.h` glue)

| Symbol | Purpose |
|--------|---------|
| `moonbit_webview_bind` | Allocates a `moonbit_webview_binding` struct to keep the MoonBit closure alive; wires it to `webview_bind` via a static trampoline. |
| `moonbit_webview_unbind` | Calls `webview_unbind` then frees the binding struct and decrements the MoonBit closure refcount. |
| `moonbit_webview_copy_cstr` | Copies a null-terminated C string into a MoonBit `Bytes` value (preserving null terminator). |
| `moonbit_run_in_background_thread` | Runs a MoonBit closure on a detached native thread. |
| `moonbit_webview_return_raw` / `moonbit_webview_terminate` | Thin wrappers over `webview_return` / `webview_terminate`. |

### `ffi/window_manager/stub.c` (window-manager runtime)

Owns the `g_wm` state machine and `moonbit_wm_*` exports: window
create/destroy/run, IPC server/client transport and framing, multi-process
spawn/connect, and platform view control (macOS Objective-C / Win32 / GTK).

Both stubs include `moonbit.h` for `moonbit_decref`, `moonbit_make_bytes_raw`,
and `moonbit_bytes_t`.

---

## JavaScript Bridge Protocol

### JS → MoonBit (Request / Reply)

```js
// Via CommandBridge
const response = await window.lepusBridge.send(commandName, payload);
// response: { status: "ok"|"error", payload?: any, error?: string }

// Via PluginHost shorthand
const response = await window.lepusApi["pluginName"]["apiName"](payload);
```

### MoonBit → JS (Fire-and-Forget)

```moonbit
bridge.send("eventName", payload)         // CommandBridge
host.emit("pluginName", "eventName", payload)  // PluginHost
webview.emit_plugin("pluginName", "eventName", payload)  // WebView shorthand
```

```js
window.lepusBridge.onCommand(listener);          // raw bridge
window.lepusApi["pluginName"]["@@on"](listener);        // plugin-scoped
window.lepusApi["pluginName"]["@@onEvent"](name, fn);   // named event
```

### Command Name Convention for Plugins

Plugin commands are routed through a namespaced command name:

```
plugin:"<plugin_name>":"<api_name>"
```

Both segments are JSON-quoted, ensuring that names containing special characters
(colons, quotes, backslashes) are handled safely.

---

## Platform Notes

| Platform | Backend | Library file |
|----------|---------|-------------|
| macOS | WebKit (WKWebView) | `lib/libwebview.dylib` |
| Linux | WebKitGTK | `lib/libwebview.dylib` |
| Windows | WebView2 (Chromium) | `lib/webview.dll` + `lib/webview.lib` |

- On macOS/Linux the link flags are `-Llib -lwebview -Wl,-rpath,lib`.
- On Windows uncomment `"cc-link-flags": "lib/webview.lib"` in `moon.pkg` and
  `example/moon.pkg`.
- The package is configured for native builds. WASM targets are not
  supported because the underlying C library requires native OS APIs.
