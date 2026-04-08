# Lepus Plugin Matrix

Source of truth for the plugin list:
- Tauri plugins workspace: https://github.com/tauri-apps/plugins-workspace
- GitHub API plugin directory listing: https://api.github.com/repos/tauri-apps/plugins-workspace/contents/plugins

## Current Status

Implemented as register-style Lepus plugins with examples:
- autostart: placeholder plugin, explicit unsupported error
- barcode_scanner: browser capability example
- biometric: browser capability example
- cli: browser location/query example
- clipboard_manager: browser clipboard example
- deep_link: browser location/protocol example
- dialog: browser confirm example
- fs: localStorage-backed example
- geolocation: browser geolocation example
- global-shortcut: browser key listener example
- haptics: browser vibration example
- http: browser fetch example
- localhost: placeholder plugin, explicit unsupported error
- log: browser console logging example
- nfc: browser capability example
- notification: browser notification example
- opener: browser window.open example
- os: browser navigator info example
- persisted_scope: localStorage-backed scope example
- positioner: placeholder plugin, explicit unsupported error
- process: browser document/location example
- shell: browser external-open example
- single_instance: BroadcastChannel example
- sql: placeholder plugin, explicit unsupported error
- store: localStorage-backed example
- stronghold: placeholder plugin, explicit unsupported error
- updater: placeholder plugin, explicit unsupported error
- upload: FormData example
- websocket: browser WebSocket capability example
- window_state: localStorage-backed window state example

## Conventions

- Every plugin package exports `plugin()`.
- Every example installs the plugin through `.plugin(@lepus_plugin_x.plugin())`.
- Examples render HTML via `@lepus_plugin_support.example_html(...)` and call `window.MoonBitPlugins[pluginName].example()`.
- Unsupported plugins are explicit runtime errors instead of empty shells.
