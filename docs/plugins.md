# Plugins

Official plugins are MoonBit packages under `plugins/`. Every package exports
`plugin() -> @webview.Plugin` and is installed on a `Window` or `App`.

## Install a plugin

Add both packages to `moon.pkg`:

```moonbit
import {
  "lepus-apps/lepus",
  "lepus-apps/lepus/plugins/lepus_plugin_dialog",
}
```

Install the plugin:

```moonbit nocheck
@lepus.Window(
  title="Plugin App",
  source=@lepus.Source::html("<h1>Plugin App</h1>"),
  plugins=[@lepus_plugin_dialog.plugin()],
).run()
```

Call it from JavaScript:

```js
try {
  const reply = await window.lepusApi.dialog.confirm({
    title: "Confirm",
    message: "Continue?",
    default_ok: true,
  });
} catch (error) {
  console.error(error);
}
```

All commands return promises, including MoonBit synchronous handlers. Payloads
and replies are JSON encoded; field names follow the MoonBit-derived JSON shape.
Use the matching example as the authoritative payload sample.

## Command inventory

| Plugin name | JavaScript commands |
| --- | --- |
| `autostart` | `status`, `enable`, `disable` |
| `barcode_scanner` | `scan`, `validate_ean13` |
| `biometric` | `is_available`, `authenticate` |
| `cli` | `args`, `cwd`, `info` |
| `clipboard_manager` | `read_text`, `write_text`, `clear`, `has_text` |
| `deep_link` | `parse`, `build` |
| `dialog` | `show`, `confirm` |
| `fs` | `exists`, `read_text`, `write_text`, `mkdir`, `remove`, `readdir`, `realpath`, `tmpdir`, `stat` |
| `geolocation` | `get_current`, `set_mock` |
| `global-shortcut` | `register`, `unregister`, `list` |
| `haptics` | `pulse` |
| `http` | `fetch` |
| `localhost` | `start`, `stop`, `status` |
| `log` | `info`, `warn`, `error`, `recent`, `clear` |
| `nfc` | `encode`, `decode` |
| `notification` | `send` |
| `opener` | `open`, `is_supported` |
| `os` | `os`, `arch`, `info` |
| `persisted_scope` | `set`, `get`, `remove` |
| `positioner` | `set_bounds`, `get_bounds` |
| `process` | `run` |
| `shell` | `exec` |
| `single_instance` | `acquire`, `release` |
| `sql` | `load`, `execute`, `select`, `close` |
| `store` | `set`, `get`, `remove`, `dump`, `clear` |
| `stronghold` | `set`, `get`, `set_key` |
| `updater` | `check` |
| `upload` | `save_text`, `delete` |
| `websocket` | `connect`, `send_text`, `recv_text`, `close` |
| `window_state` | `save_state`, `load_state`, `clear_state` |

## Built-in plugins

The root package installs these automatically for multi-window applications:

- `windows`: label-addressed list/open/focus/close/show/hide/move/resize and
  window-state commands.
- `events`: directed cross-window events delivered as `lepus_event`.
- current-window controls exposed through `window.LepusWindow`.

## Status and security

Not every official plugin is a production native implementation. Some are Web
API adapters, examples, in-memory/local implementations, or explicit
unsupported placeholders. Read the [Plugin Matrix](/plugin-matrix) before use.

Treat frontend input as untrusted. In particular, restrict filesystem paths,
process/shell commands, URLs, uploaded data, and SQL to the minimum capability
your application needs. Only install plugins required by the application.

## Creating a plugin

```moonbit nocheck
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin("greeting", builder => {
    builder.command_sync("hello", fn(name : String) -> String {
      "Hello, " + name
    })
  })
}
```

Frontend usage:

```js
const message = await window.lepusApi.greeting.hello("MoonBit");
```

Use `command_sync` for immediate handlers, `command`/`command_result_async` for
async handlers, and result-aware forms when the implementation may raise.
Plugin names and command names should be stable because they define the
frontend API.
