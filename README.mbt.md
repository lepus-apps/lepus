# Lepus

Lepus is a desktop application toolkit for MoonBit.

It provides:

- a native MoonBit application host
- a WebView-based rendering runtime
- a plugin system for exposing platform features to frontend code
- a MoonBit CLI for scaffolding and local workflows

## Status

Lepus is still in an early stage.

What is already in this repository:

- the core app API in [`lepus.mbt`](lepus.mbt)
- the WebView runtime in [`webview/`](webview/)
- the CLI in [`cli/lepus/`](cli/lepus/)
- official plugin packages in [`plugins/`](plugins/)
- runnable examples in [`examples/`](examples/)

What is not finished yet:

- many plugins are still example-backed or placeholders
- `dev` and `build` are still being expanded
- packaging and distribution are not production-ready yet

## Quick Start

### Requirements

You need:

- `moon`
- a native toolchain that can build MoonBit native targets
- a local environment where the bundled `webview` library can be loaded

Check your environment:

```sh
moon run --target native cli/lepus -- doctor
```

### Run an Example

Run the basic example:

```sh
moon run --target native examples/hello
```

Run a plugin example:

```sh
moon run --target native examples/dialog
```

### Create a New App

```sh
moon run --target native cli/lepus -- init my-app
```

## API

The current top-level API is centered around `App::new(...)`.

Minimal app:

```moonbit nocheck
///|
fn main {
  @lepus.App::new(
    title="Hello Lepus",
    html=(
      #|<!doctype html>
      #|<html><body><h1>Hello Lepus</h1></body></html>,
    ),
  ).run()
}
```

Plugin-enabled app:

```moonbit nocheck
///|
fn main {
  @lepus.App::new(
    title="Dialog Example",
    html=@lepus_plugin_support.example_html("dialog", "Dialog Plugin Example"),
    plugins=[@lepus_plugin_dialog.plugin()],
  ).run()
}
```

## Plugins

Plugins live in [`plugins/`](plugins/).

Each plugin package exports:

- `plugin()`

Each example installs plugins through:

- `plugins=[@lepus_plugin_x.plugin()]`

The current plugin status matrix is in [`PLUGINS.md`](PLUGINS.md).

## Repository Layout

```text
.
├── cli/lepus/   # CLI implementation
├── examples/    # runnable native examples
├── plugins/     # official plugin packages
├── webview/     # WebView runtime and bridge
├── lepus.mbt    # top-level Lepus API
├── moon.pkg     # root package definition
└── moon.mod.json
```

## Development

Useful commands:

```sh
moon check
moon test --target native -p lepus-apps/lepus/webview
moon info && moon fmt
```

CLI help:

```sh
moon run --target native cli/lepus -- --help
```

## License

[Apache License 2.0](LICENSE)
