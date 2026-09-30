# Lepus

Lepus is a native desktop application toolkit for MoonBit. It combines a
WebView runtime, typed MoonBit-to-JavaScript commands, multi-window management,
official plugins, and a project CLI.

> Lepus is under active development. Check [platform support](docs/platform-support.md)
> and the [plugin matrix](PLUGINS.md) before relying on a capability in production.

## Features

- Single-window and multi-window native applications
- Inline HTML, local directories, remote URLs, and in-memory ZIP assets
- Single-process and process-per-window execution models
- Typed plugins exposed as `window.lepusApi.<plugin>.<command>`
- Built-in window controls and cross-window events
- CLI workflows for setup, development, build, doctor, and bundling

## Requirements

- MoonBit toolchain with native target support
- A C toolchain supported by MoonBit
- Native WebView dependencies for the current platform
- Node.js/npm only when using a frontend project with `package.json`

Check the local environment:

```sh
moon run --target native cli/lepus -- doctor
```

## Install

Add Lepus to a MoonBit module:

```sh
moon add lepus-apps/lepus
```

A package using the high-level API imports the root package:

```moonbit nocheck
///|
import {
  "lepus-apps/lepus",
}
```

## Quick Start

The smallest application uses `Window` and an in-memory HTML source:

```moonbit nocheck
///|
async fn main {
  @lepus.Window(
    title="Hello Lepus",
    width=800,
    height=600,
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><body><h1>Hello from MoonBit</h1></body></html>
      ),
    ),
  ).run()
}
```

The construction API used above is checked as part of the package tests:

```mbt check
///|
test "construct a Lepus app" {
  let window = @lepus.WindowConfig::new(
    label="main",
    title="Hello Lepus",
    source=@lepus.Source::html("<h1>Hello</h1>"),
  )
  let app = @lepus.App::new([window])
  assert_eq(app.window_count(), 1)
  assert_eq(window.label(), "main")
}
```

Run the included example:

```sh
moon run --target native examples/hello
```

## Sources

`Source` selects what a window loads:

```moonbit nocheck
///|
let remote = @lepus.Source::Url("https://example.com")

///|
let local = @lepus.Source::Local("./dist")

///|
let inline = @lepus.Source::html("<h1>Inline HTML</h1>")

///|
let archived = @lepus.Source::zip(zip_bytes)
```

- `Url` navigates directly to a URL.
- `Local` serves a local directory through a generated custom protocol.
- `Memory` serves an in-memory file set; `Source::html` and `Source::zip` build it.
- `WindowConfig::source` is required when a window starts.

See [Core API](docs/core-api.md) for source and configuration details.

## Multiple Windows

For most applications, prefer `run_single_process`: all windows share one
native application, event loop, and plugin host process.

```moonbit nocheck
///|
async fn main {
  let main = @lepus.WindowConfig::new(
    label="main",
    title="Main",
    source=@lepus.Source::html("<h1>Main</h1>"),
  )
  let settings = @lepus.WindowConfig::new(
    label="settings",
    title="Settings",
    hidden=true,
    source=@lepus.Source::html("<h1>Settings</h1>"),
  )
  @lepus.App::new([main, settings]).run_single_process()
}
```

Use `App::run` only when process isolation per window is required. Window
labels must be unique in both modes.

See [Windows and events](docs/windows.md).

## Plugins

Install plugins on `Window` or `App`:

```moonbit nocheck
///|
async fn main {
  @lepus.Window(
    title="Dialog",
    source=@lepus.Source::html("<button onclick='showDialog()'>Open</button>"),
    plugins=[@lepus_plugin_dialog.plugin()],
  ).run()
}
```

Frontend commands are promises:

```js
const reply = await window.lepusApi.dialog.confirm({
  title: "Confirm",
  message: "Continue?",
  default_ok: true,
});
```

Every official plugin exports `plugin()`. The complete command inventory and
implementation status are documented in [Plugins](docs/plugins.md) and
[Plugin Matrix](PLUGINS.md).

## CLI

```sh
moon run --target native cli/lepus -- setup
moon run --target native cli/lepus -- dev
moon run --target native cli/lepus -- build
moon run --target native cli/lepus -- bundle
```

See [CLI reference](docs/cli.md) for all commands and options.

## Documentation

- [Getting started](docs/getting-started.md)
- [Core API](docs/core-api.md)
- [Windows and events](docs/windows.md)
- [Plugins](docs/plugins.md)
- [CLI reference](docs/cli.md)
- [Architecture](docs/architecture.md)
- [Platform support](docs/platform-support.md)
- [Low-level WebView API](webview/README.mbt.md)
- [Runnable examples](examples/)

## Development

```sh
moon check
moon test --target native
moon info && moon fmt
```

Run CLI help with:

```sh
moon run --target native cli/lepus -- --help
```

## License

[Apache License 2.0](LICENSE)
