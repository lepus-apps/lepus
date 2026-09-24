///|
/// A minimal multi-window app: two windows created from one `App`.
///
/// Each window is given a stable `label` and independent content. The App host
/// spawns one child process per window and serves all of them until the last
/// window closes.
async fn main {
  let main_window = @lepus.WindowConfig::new(
    label="main",
    title="Lepus Multi-Window — Main",
    width=720,
    height=520,
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><head><style>
        #|  body { font-family: -apple-system, sans-serif; display: grid;
        #|         place-items: center; height: 100vh; margin: 0; background: #f5f7fa; }
        #|  .card { background: #fff; border-radius: 12px; padding: 32px 48px;
        #|          box-shadow: 0 8px 30px rgba(0,0,0,.08); text-align: center; }
        #|  h1 { margin: 0 0 8px; color: #2c3e50; }
        #|  p { color: #7f8c8d; margin: 0; }
        #|  code { color: #1769ff; }
        #|</style></head>
        #|<body><div class="card">
        #|  <h1>Main window</h1>
        #|  <p>Label: <code>main</code></p>
        #|</div></body></html>
      ),
    ),
  )
  let settings_window = @lepus.WindowConfig::new(
    label="settings",
    title="Settings",
    width=480,
    height=360,
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><head><style>
        #|  body { font-family: -apple-system, sans-serif; display: grid;
        #|         place-items: center; height: 100vh; margin: 0; background: #eef2f7; }
        #|  .card { background: #fff; border-radius: 12px; padding: 28px 40px;
        #|          box-shadow: 0 8px 30px rgba(0,0,0,.08); text-align: center; }
        #|  h1 { margin: 0 0 8px; color: #2c3e50; font-size: 24px; }
        #|  p { color: #7f8c8d; margin: 0; }
        #|  code { color: #1769ff; }
        #|</style></head>
        #|<body><div class="card">
        #|  <h1>Settings window</h1>
        #|  <p>Label: <code>settings</code></p>
        #|</div></body></html>
      ),
    ),
  )
  @lepus.App::new([main_window, settings_window]).run()
}
