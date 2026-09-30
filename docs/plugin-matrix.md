# Plugin Matrix

Every package below exports `plugin()` and has a runnable example under
`examples/<name>` unless noted otherwise. Frontend APIs are available under
`window.lepusApi.<plugin-name>`.

Status meanings:

- **Native**: implemented with MoonBit/native facilities.
- **Web API**: adapts a browser/WebView capability.
- **Local model**: functional local or in-memory behavior, not a full OS service.
- **Placeholder**: deliberately reports unsupported or supplies only model logic.

| Package | Frontend name | Commands | Status |
| --- | --- | --- | --- |
| `lepus_plugin_autostart` | `autostart` | `status`, `enable`, `disable` | Placeholder |
| `lepus_plugin_barcode_scanner` | `barcode_scanner` | `scan`, `validate_ean13` | Local model |
| `lepus_plugin_biometric` | `biometric` | `is_available`, `authenticate` | Web API/capability model |
| `lepus_plugin_cli` | `cli` | `args`, `cwd`, `info` | Native/local |
| `lepus_plugin_clipboard_manager` | `clipboard_manager` | `read_text`, `write_text`, `clear`, `has_text` | Web API |
| `lepus_plugin_deep_link` | `deep_link` | `parse`, `build` | Local model |
| `lepus_plugin_dialog` | `dialog` | `show`, `confirm` | Web API |
| `lepus_plugin_fs` | `fs` | `exists`, `read_text`, `write_text`, `mkdir`, `remove`, `readdir`, `realpath`, `tmpdir`, `stat` | Native |
| `lepus_plugin_geolocation` | `geolocation` | `get_current`, `set_mock` | Local model |
| `lepus_plugin_global_shortcut` | `global-shortcut` | `register`, `unregister`, `list` | Web event model |
| `lepus_plugin_haptics` | `haptics` | `pulse` | Web API |
| `lepus_plugin_http` | `http` | `fetch` | Web API |
| `lepus_plugin_localhost` | `localhost` | `start`, `stop`, `status` | Placeholder |
| `lepus_plugin_log` | `log` | `info`, `warn`, `error`, `recent`, `clear` | Local model |
| `lepus_plugin_nfc` | `nfc` | `encode`, `decode` | Local model |
| `lepus_plugin_notification` | `notification` | `send` | Web API |
| `lepus_plugin_opener` | `opener` | `open`, `is_supported` | Web API |
| `lepus_plugin_os` | `os` | `os`, `arch`, `info` | Native/local |
| `lepus_plugin_persisted_scope` | `persisted_scope` | `set`, `get`, `remove` | Local model |
| `lepus_plugin_positioner` | `positioner` | `set_bounds`, `get_bounds` | Placeholder/local model |
| `lepus_plugin_process` | `process` | `run` | Native |
| `lepus_plugin_shell` | `shell` | `exec` | Native |
| `lepus_plugin_single_instance` | `single_instance` | `acquire`, `release` | Local model |
| `lepus_plugin_sql` | `sql` | `load`, `execute`, `select`, `close` | Placeholder/local model |
| `lepus_plugin_store` | `store` | `set`, `get`, `remove`, `dump`, `clear` | Local model |
| `lepus_plugin_stronghold` | `stronghold` | `set`, `get`, `set_key` | Placeholder/local model |
| `lepus_plugin_updater` | `updater` | `check` | Placeholder/local model |
| `lepus_plugin_upload` | `upload` | `save_text`, `delete` | Native |
| `lepus_plugin_websocket` | `websocket` | `connect`, `send_text`, `recv_text`, `close` | Local model |
| `lepus_plugin_window_state` | `window_state` | `save_state`, `load_state`, `clear_state` | Local model |

`lepus_plugin_support` is an example helper package and does not install a
frontend plugin. It exports `example_html(...)` for repository demos.

## Conventions

- Install with `plugins=[@lepus_plugin_x.plugin()]`.
- Await every JavaScript command.
- Command failures reject the returned promise.
- Unsupported capabilities fail explicitly rather than silently succeeding.
- Examples under `examples/` are the payload/reply reference for each plugin.

See [Plugins](/plugins) for installation, custom plugin, built-in, and security
guidance.
