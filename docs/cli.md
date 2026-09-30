# CLI Reference

Run the repository CLI with:

```sh
moon run --target native cli/lepus -- <command> [options]
```

Global options:

| Option | Meaning |
| --- | --- |
| `--cwd <path>` | Application directory; defaults to the current directory. |
| `--config <path>` | Explicit Lepus configuration path where supported. |
| `-v`, `--verbose` | Increase verbosity; repeatable. |

## `init`

```sh
lepus init [name] [--template basic] [--frontend vanilla] [--force]
```

The parser currently advertises this command and accepts template `basic`,
frontend `vanilla`, and `--force`, but `run_cli` does not yet dispatch `init`.
Invoking it currently returns an unknown-command error; create the MoonBit
module manually until the command is connected.

## `setup`

```sh
lepus setup [--force]
```

Locates the Lepus source in the current module or
`.mooncakes/lepus-apps/lepus`, then builds the helper executables under
`cli/cc` and `cli/lepus` in release mode. Existing helpers are reused unless
`--force` is supplied.

## `dev`

```sh
lepus dev [--frontend-dir <path>] [--host <host>] [--port <port>] [--skip-setup]
```

- Defaults to host `127.0.0.1` and port `2333`.
- If `<frontend-dir>/package.json` exists, ensures npm dependencies are ready,
  starts local Vite with `--strictPort`, then runs the MoonBit app with
  `LEPUS_DEV_URL` set.
- Without `package.json`, runs `moon run --target native main.mbt` directly.

## `build`

```sh
lepus build [--debug] [--frontend-dir <path>] [--dist-dir <path>]
            [--out-dir <path>] [--no-typecheck] [--skip-frontend]
            [--skip-moon] [--skip-setup]
```

The default workflow:

1. Prepare Lepus helper tools.
2. If a frontend `package.json` exists, run TypeScript checking when a
   `tsconfig.json` exists, then run `vite build`.
3. Archive the frontend dist directory as `<out-dir>/dist.zip` (default
   `_build/dist.zip`).
4. Run `moon build --release`.

`--debug` changes the MoonBit build to non-release mode. Skip flags allow each
stage to be run independently.

## `bundle`

```sh
lepus bundle [--app-id <id>] [--app-name <name>] [--app-version <version>]
             [--icon <path>] [--bin <path>] [--frontend-dir <path>]
             [--out-dir <path>] [--skip-build] [--skip-setup]
```

Creates a platform application bundle. Defaults are derived from `moon.mod`:

- app id: `com.<module-name-with-dots>`
- app name: title-cased module basename
- version: `1.0.0`
- output directory: `bundle`

Without `--bin`, the command searches `_build/native/release/build` for the
release executable. macOS creates an `.app`; Linux and Windows create their
platform directory layouts.

## `doctor`

```sh
lepus doctor [--json]
```

Checks:

- `moon` availability
- a `moon.mod` or legacy `moon.mod.json` in `cwd`
- `lepus.conf.json`, `lepus.json`, or `--config`
- WebView library search environment
- recognized desktop platform

Exit code is `0` only when every check passes. `--json` emits machine-readable
check objects.
