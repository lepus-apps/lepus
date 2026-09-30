# Windows and Events

Lepus supports one or many windows, stable label-based addressing, and two
execution models.

## Execution models

### Single process

```moonbit nocheck
@lepus.App::new([main, settings]).run_single_process()
```

This mode creates every WebView in the current process. Windows share one
native application, menu/event loop, and plugin process. Cross-window events
are delivered directly with `WebView::eval`. This is the recommended mode for
most applications.

### Process per window

```moonbit nocheck
@lepus.App::new([main, settings]).run()
```

The main process routes commands and each selected window runs in a child
process. This provides isolation but adds IPC and process lifecycle complexity.
A window declared with `hidden=true` is spawned lazily when `windows.open` is
called.

## Labels

Every window has a resolved label:

1. Explicit `label` when non-empty
2. `title`
3. `Lepus App`

Labels must be unique. Use explicit labels for any app with more than one
window because all window control and event APIs address labels.

## Built-in `windows` frontend API

Multi-window apps expose `window.lepusApi.windows`:

| Command | Payload | Result |
| --- | --- | --- |
| `list()` | none | `{ label, open }[]` |
| `open({ label })` | target label | `boolean` |
| `focus({ label })` | target label | `boolean` |
| `close({ label })` | target label | `boolean` |
| `show({ label })` | target label | `boolean` |
| `hide({ label })` | target label | `boolean` |
| `move({ label, x, y })` | absolute position | `boolean` |
| `resize({ label, width, height })` | new size | `boolean` |
| `minimize({ label })` | target label | `boolean` |
| `maximize({ label })` | target label | `boolean` |
| `set_fullscreen({ label, fullscreen })` | target state | `boolean` |

A `false` result means the label is unknown, the target is not open for an
operation requiring an open window, or the native/IPC operation failed.

## Current-window controls

Each window also receives `window.LepusWindow`, used by the built-in controls
plugin. Common operations include:

```js
window.LepusWindow.minimize();
window.LepusWindow.toggleMaximize();
window.LepusWindow.setFullscreen(true);
window.LepusWindow.startDrag();
window.LepusWindow.close();
```

The low-level facade also supports show/hide, focus, position, size, reload,
navigation history, and developer tools where supported.

## Cross-window events

Send an event from frontend code:

```js
const delivered = await window.lepusApi.events.emit({
  target: "settings",
  event: "theme",
  payload: { name: "dark" },
});
```

Receive it in the target window:

```js
window.addEventListener("lepus_event", (event) => {
  const { event: name, payload } = event.detail;
  console.log(name, payload);
});
```

`emit` returns `false` for an unknown target. In single-process mode delivery is
a direct eval; in process-per-window mode it is a directed IPC event.

## Lazy windows

In process-per-window mode, use `hidden=true` for windows that should not spawn
at startup. Calling `windows.open({ label })` starts the child process on first
use. Later calls show the existing window and focus it unless `focused=false`.

See `examples/multi_window` and `examples/cross_window` for complete programs.
