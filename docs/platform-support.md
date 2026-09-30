# Platform Support

Lepus is a native-only MoonBit project. Platform behavior depends on both the
WebView backend and the window-manager FFI implementation.

## Current support

| Platform | Build/runtime status | Bundle output | Notes |
| --- | --- | --- | --- |
| macOS arm64/x86_64 | Primary development target | `.app` | Uses the system WebKit stack; supports macOS-specific title-bar options. |
| Linux arm64/x86_64 | Supported by CLI checks | AppDir-style directory | Requires a compatible WebKit/WebView runtime and shared-library setup. |
| Windows arm64/x86_64 | Target is modeled | Directory bundle | Runtime and packaging should be validated on the target machine. |
| iOS / Android / OpenHarmony | Detectable platform values only | Not supported | No desktop bundle workflow. |

`lepus doctor` currently considers macOS and Linux supported environments.
Windows bundling code exists, but the doctor support gate and runtime should be
verified before release use.

## Window option portability

These options are platform-dependent even when accepted by the API:

- `traffic_light_position` is macOS-specific.
- `title_bar_style`, `title_bar_overlay`, and `hidden_title` depend on native
  title-bar support.
- `transparent` requires compositor and WebView support.
- `always_on_bottom`, `skip_taskbar`, and `visible_on_all_workspaces` may have
  different native semantics.
- `devtools` availability depends on the WebView backend and build.

Unspecified options preserve native defaults. Prefer capability testing on each
shipping platform rather than assuming identical behavior.

## Plugin portability

Official plugins fall into three groups:

1. Native MoonBit implementations such as filesystem/process operations.
2. Web platform adapters such as Notification, Clipboard, Geolocation, Fetch,
   WebSocket, and browser capability checks.
3. Explicit placeholders that return unsupported results until a native backend
   is implemented.

See the [Plugin Matrix](/plugin-matrix) for the status of every plugin.

## Runtime libraries

The native executable must be able to resolve the bundled/system WebView
library. Use:

```sh
moon run --target native cli/lepus -- doctor
```

For local development, library lookup may use `DYLD_LIBRARY_PATH`,
`LD_LIBRARY_PATH`, or the platform `PATH`. Production bundles should include or
reference the correct runtime according to the target platform.
