///|
/// A window-managed multi-window app: the main "workspace" window opens and
/// controls a settings window and an inspector window entirely at runtime.
///
/// The settings and inspector windows are declared with `hidden=true`, so they
/// are not created up front. Clicking a button in the main window spawns them
/// on demand (`window.lepusApi.windows.open`) and afterwards can move, resize,
/// show, hide, minimize, maximize, fullscreen, or close them — all addressed by
/// a stable `label`. Windows also talk to each other through the cross-window
/// event bus (`window.lepusApi.events.emit` / `window.addEventListener("lepus_event")`).
async fn main {
  let main_window = @lepus.WindowConfig::new(
    label="main",
    title="Lepus Workspace",
    width=680,
    height=520,
    position=(80, 80),
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><head><style>
        #|  body { font-family: -apple-system, sans-serif; margin: 0; background: #f5f7fa;
        #|         display: flex; justify-content: center; padding: 32px 0; }
        #|  .app { width: 600px; }
        #|  h1 { margin: 0 0 4px; font-size: 22px; color: #2c3e50; }
        #|  .sub { color: #7f8c8d; font-size: 13px; margin: 0 0 20px; }
        #|  .section { background: #fff; border-radius: 12px; padding: 20px 22px;
        #|             box-shadow: 0 6px 24px rgba(0,0,0,.06); margin-bottom: 16px; }
        #|  .section h2 { margin: 0 0 12px; font-size: 14px; color: #2c3e50;
        #|                 text-transform: uppercase; letter-spacing: .5px; }
        #|  .row { display: flex; flex-wrap: wrap; gap: 8px; }
        #|  button { border: none; border-radius: 8px; padding: 9px 14px; cursor: pointer;
        #|           font-size: 13px; font-weight: 600; background: #eef2f7; color: #2c3e50; }
        #|  button:hover { background: #dfe6ef; }
        #|  button.primary { background: #1769ff; color: #fff; }
        #|  button.primary:hover { background: #0d52d4; }
        #|  button.danger { background: #ff4d4d; color: #fff; }
        #|  button.danger:hover { background: #d42f2f; }
        #|  #status { font-family: monospace; font-size: 12px; color: #7f8c8d;
        #|            white-space: pre-wrap; background: #f0f2f5; border-radius: 8px;
        #|            padding: 12px; min-height: 56px; margin-top: 12px; }
        #|</style></head>
        #|<body><div class="app">
        #|  <h1>Lepus Workspace</h1>
        #|  <p class="sub">Main window — manages every other window by label at runtime.</p>
        #|
        #|  <div class="section">
        #|    <h2>Open / close</h2>
        #|    <div class="row">
        #|      <button class="primary" onclick="openWindow('settings')">Open Settings</button>
        #|      <button class="primary" onclick="openWindow('inspector')">Open Inspector</button>
        #|      <button class="danger" onclick="wm('close','settings')">Close Settings</button>
        #|      <button class="danger" onclick="wm('close','inspector')">Close Inspector</button>
        #|      <button onclick="refresh()">Refresh list</button>
        #|    </div>
        #|  </div>
        #|
        #|  <div class="section">
        #|    <h2>Position (settings)</h2>
        #|    <div class="row">
        #|      <button onclick="move('settings', 780, 80)">Right of main</button>
        #|      <button onclick="move('settings', 120, 620)">Bottom-left</button>
        #|      <button onclick="move('settings', 820, 620)">Bottom-right</button>
        #|      <button onclick="move('settings', 400, 200)">Center</button>
        #|    </div>
        #|  </div>
        #|
        #|  <div class="section">
        #|    <h2>Resize &amp; state (settings)</h2>
        #|    <div class="row">
        #|      <button onclick="resize('settings', 520, 400)">520×400</button>
        #|      <button onclick="resize('settings', 360, 260)">360×260</button>
        #|      <button onclick="wm('show','settings')">Show</button>
        #|      <button onclick="wm('hide','settings')">Hide</button>
        #|      <button onclick="wm('minimize','settings')">Minimize</button>
        #|      <button onclick="wm('maximize','settings')">Maximize</button>
        #|      <button onclick="fullscreen('settings', true)">Fullscreen</button>
        #|    </div>
        #|  </div>
        #|
        #|  <div class="section">
        #|    <h2>Cross-window message</h2>
        #|    <div class="row">
        #|      <button onclick="send('settings', 'theme', { name: 'dark' })">Send to Settings</button>
        #|      <button onclick="send('inspector', 'focus', { file: 'src/main.mbt' })">Send to Inspector</button>
        #|    </div>
        #|  </div>
        #|
        #|  <div id="status">ready — click a button</div>
        #|
        #|<script>
        #|  const status = document.getElementById("status");
        #|  const wm = (name, label) =>
        #|    window.lepusApi.windows[name]({ label }).then(ok => log(`${name}(${label}) → ${ok}`));
        #|  const openWindow = async (label) => {
        #|    const ok = await window.lepusApi.windows.open({ label });
        #|    log(`open(${label}) → ${ok}`);
        #|    move(label, label === "settings" ? 780 : 680, 80);
        #|  };
        #|  const move = (label, x, y) => wmAt('move', label, { x, y });
        #|  const wmAt = (name, label, extra) =>
        #|    window.lepusApi.windows[name]({ label, ...extra })
        #|      .then(ok => log(`${name}(${label}) → ${ok}`));
        #|  const resize = (label, width, height) => wmAt('resize', label, { width, height });
        #|  const fullscreen = (label, v) => wmAt('set_fullscreen', label, { fullscreen: v });
        #|  const send = (target, event, payload) =>
        #|    window.lepusApi.events.emit({ target, event, payload })
        #|      .then(ok => log(`emit → ${target} "${event}" ${ok ? 'sent' : 'failed'}`));
        #|  const refresh = async () => {
        #|    const list = await window.lepusApi.windows.list();
        #|    log('windows: ' + list.map(w => `${w.label}${w.open ? '(open)' : '(closed)'}`).join(', '));
        #|  };
        #|  function log(msg) { status.textContent = msg + '\n' + status.textContent; }
        #|  refresh();
        #|</script>
        #|</div></body></html>
      ),
    ),
  )
  let settings_window = @lepus.WindowConfig::new(
    label="settings",
    title="Settings",
    width=420,
    height=360,
    hidden=true,
    position=(780, 80),
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><head><style>
        #|  body { font-family: -apple-system, sans-serif; margin: 0; background: #eef2f7;
        #|         display: flex; justify-content: center; padding: 28px 0; }
        #|  .card { background: #fff; border-radius: 12px; padding: 24px 28px;
        #|          box-shadow: 0 8px 30px rgba(0,0,0,.08); width: 360px; }
        #|  h1 { margin: 0 0 6px; font-size: 20px; color: #2c3e50; }
        #|  p { color: #7f8c8d; font-size: 13px; margin: 0 0 16px; }
        #|  label { font-size: 13px; color: #2c3e50; display: block; margin: 12px 0 4px; }
        #|  select, input { width: 100%; padding: 8px; border-radius: 8px; border: 1px solid #ccd7e2; }
        #|  #events { font-family: monospace; font-size: 12px; color: #1769ff; background: #f0f2f5;
        #|            border-radius: 8px; padding: 10px; margin-top: 16px; white-space: pre-wrap; min-height: 40px; }
        #|  .row { display: flex; gap: 8px; margin-top: 16px; }
        #|  button { border: none; border-radius: 8px; padding: 8px 12px; cursor: pointer;
        #|           font-weight: 600; background: #eef2f7; color: #2c3e50; }
        #|  button.danger { background: #ff4d4d; color: #fff; }
        #|</style></head>
        #|<body><div class="card">
        #|  <h1>Settings</h1>
        #|  <p>This window was opened at runtime by <code>Label: settings</code>.</p>
        #|  <label>Theme</label>
        #|  <select><option>system</option><option>light</option><option>dark</option></select>
        #|  <label>Notifications</label>
        #|  <input type="checkbox" checked />
        #|  <div class="row">
        #|    <button onclick="window.LepusWindow.hide()">Hide self</button>
        #|    <button class="danger" onclick="window.LepusWindow.close()">Close self</button>
        #|  </div>
        #|  <div id="events">listening for messages…</div>
        #|<script>
        #|  const events = document.getElementById("events");
        #|  window.addEventListener("lepus_event", (e) => {
        #|    const { event, payload } = e.detail;
        #|    events.textContent = `[${event}] ${JSON.stringify(payload)}`;
        #|  });
        #|</script>
        #|</div></body></html>
      ),
    ),
  )
  let inspector_window = @lepus.WindowConfig::new(
    label="inspector",
    title="Inspector",
    width=460,
    height=320,
    hidden=true,
    position=(680, 460),
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><head><style>
        #|  body { font-family: -apple-system, sans-serif; margin: 0; background: #f0f4f8;
        #|         display: flex; justify-content: center; padding: 28px 0; }
        #|  .card { background: #fff; border-radius: 12px; padding: 24px 28px;
        #|          box-shadow: 0 8px 30px rgba(0,0,0,.08); width: 380px; }
        #|  h1 { margin: 0 0 6px; font-size: 20px; color: #2c3e50; }
        #|  p { color: #7f8c8d; font-size: 13px; margin: 0 0 14px; }
        #|  #events { font-family: monospace; font-size: 12px; color: #1769ff; background: #f0f2f5;
        #|            border-radius: 8px; padding: 10px; white-space: pre-wrap; min-height: 40px; }
        #|</style></head>
        #|<body><div class="card">
        #|  <h1>Inspector</h1>
        #|  <p>Opened at runtime by <code>Label: inspector</code>.</p>
        #|  <div id="events">listening for messages…</div>
        #|<script>
        #|  const events = document.getElementById("events");
        #|  window.addEventListener("lepus_event", (e) => {
        #|    const { event, payload } = e.detail;
        #|    events.textContent = `[${event}] ${JSON.stringify(payload)}`;
        #|  });
        #|</script>
        #|</div></body></html>
      ),
    ),
  )
  @lepus.Windows::new([main_window, settings_window, inspector_window]).run()
}
