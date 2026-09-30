# Core API

Package: `lepus-apps/lepus`

The root package is the recommended application-level API. It wraps the lower
level `webview` package and adds source resolution, window configuration,
plugins, event delivery, and multi-window lifecycle management.

## `Source`

| Variant/helper | Purpose |
| --- | --- |
| `Source::Url(url)` | Navigate to an HTTP(S) or custom URL. |
| `Source::Local(path)` | Serve a local directory through a generated custom protocol. |
| `Source::Memory(source)` | Serve an in-memory file collection. |
| `Source::html(html)` | Create a memory source containing `index.html`. |
| `Source::zip(bytes)` | Extract files from ZIP bytes into a memory source. Raises for invalid ZIP data. |

`MemorySource(files, entry?)` defaults its entry to `index.html`.
`MemoryFile::from_string` UTF-8 encodes text; `from_bytes` preserves raw bytes.
Paths should use forward slashes and the entry must identify a file in the set.

## `WindowConfig`

All native options are optional. An omitted field leaves the platform default
unchanged and does not issue a native configuration call.

| Field | Meaning |
| --- | --- |
| `label` | Stable cross-window identifier. Falls back to title, then `Lepus App`. |
| `title` | Native window title. |
| `width`, `height` | Initial client size. |
| `position` | Initial absolute `(x, y)` position. |
| `hidden` | Create or declare the window without initially showing it. |
| `focused` | Whether opening/showing should take focus; defaults to native focus behavior. |
| `debug` | Native WebView debug mode value. |
| `devtools` | Enable WebView developer tools. |
| `decorations` | OS title bar and border. `false` creates a frameless window. |
| `frameless` | Compatibility alias that sets `decorations=false`. |
| `resizable` | Allow user resize. |
| `closeable` | Enable the close action. |
| `minimizable`, `maximizable` | Enable corresponding native actions. |
| `always_on_top`, `always_on_bottom` | Window stacking preference. |
| `transparent` | Enable a transparent native background. |
| `shadow` | Native window shadow. |
| `skip_taskbar` | Hide from the taskbar/dock where supported. |
| `visible_on_all_workspaces` | Show on every workspace where supported. |
| `title_bar_style` | `Visible`, `Transparent`, or `Overlay`. |
| `title_bar_overlay` | Extend content into the title-bar area. |
| `hidden_title` | Hide native title text where supported. |
| `traffic_light_position` | macOS traffic-light `(x, y)` position. |
| `source` | Required content source. |

Methods:

- `WindowConfig::new(...)` creates a configuration.
- `config.label()` returns the resolved label.
- `config.set_source(source)` returns an updated copy.
- `config.navigate(url)` returns a copy using `Source::Url(url)`.

## Single-window `Window`

`Window(...)` accepts all `WindowConfig` options plus `plugins`. It is the
simplest entry point:

```moonbit nocheck
@lepus.Window(
  title="Hello",
  source=@lepus.Source::html("<h1>Hello</h1>"),
  plugins=[@lepus_plugin_log.plugin()],
).run()
```

`Window::set_source` and `Window::navigate` return updated values. `Window::run`
starts the application and waits until it exits.

## `App`

- `App::new(windows, plugins?)` creates an app. It may be constructed empty, but
  running an empty app aborts.
- `App::with_windows(windows, plugins?)` requires at least one window immediately.
- `add_window(config)` appends a configuration.
- `window_count()` returns the number of declared windows.
- `run(window_index?)` uses process-per-window execution. Passing an index runs
  only that configured window.
- `run_single_process()` creates all windows in one process and is recommended
  for most desktop applications.

Both run modes require unique resolved labels and a source for every window.

## Title-bar styles

- `Visible`: normal native title bar.
- `Transparent`: transparent native title bar remains present.
- `Overlay`: application content extends beneath the native title-bar area.

Custom title-bar support is injected for frameless/decorations-disabled,
transparent-title-bar, overlay-title-bar, or title-bar-overlay configurations.
Use `.lepus-drag` or `[data-lepus-drag="true"]` for draggable content and
`.lepus-no-drag` for interactive descendants.
