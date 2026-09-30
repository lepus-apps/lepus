# Getting Started

This guide creates and runs a minimal Lepus application.

## 1. Prepare a MoonBit module

Add the dependency from the application root:

```sh
moon add lepus-apps/lepus
```

Import Lepus from the package containing the executable:

```moonbit
import {
  "lepus-apps/lepus",
}

options(
  is-main: true,
)
```

Lepus currently targets native builds.

## 2. Create the application

Create `main.mbt`:

```moonbit
///|
async fn main {
  @lepus.Window(
    label="main",
    title="My Lepus App",
    width=960,
    height=640,
    source=@lepus.Source::html(
      #|<!doctype html>
      #|<html>
      #|  <body>
      #|    <h1>My Lepus App</h1>
      #|  </body>
      #|</html>
    ),
  ).run()
}
```

`Window(...)` is the convenience API for one window. For multiple windows,
construct `WindowConfig` values and pass them to `App::new`.

## 3. Check the environment

From the Lepus source checkout:

```sh
moon run --target native cli/lepus -- doctor --cwd /path/to/app
```

The doctor checks MoonBit, module/config presence, WebView library resolution,
and the current platform.

## 4. Run

For an application without a frontend package:

```sh
moon run --target native main.mbt
```

When using the Lepus CLI:

```sh
moon run --target native /path/to/lepus/cli/lepus -- dev --cwd /path/to/app
```

If the frontend directory contains `package.json`, `dev` starts Vite at
`127.0.0.1:2333` by default and sets `LEPUS_DEV_URL` for the native process.
Otherwise it runs the MoonBit entry directly.

## 5. Choose a source

- `Source::html(text)` for self-contained pages and prototypes.
- `Source::Local(path)` for built frontend assets.
- `Source::Url(url)` for a development server or remote page.
- `Source::zip(bytes)` for an in-memory frontend archive.

Use `WindowConfig::set_source` to replace a source, or `navigate(url)` as a
shortcut for `Source::Url(url)`.

## Next steps

- Configure windows: [Windows and events](windows.md)
- Install native capabilities: [Plugins](plugins.md)
- Build and package: [CLI reference](cli.md)
- Understand process boundaries: [Architecture](architecture.md)
