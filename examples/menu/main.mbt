///|
async fn main {
  @lepus.Window::new(
    title="Lepus Menu Plugin",
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html>
        #|<head>
        #|  <meta charset="utf-8" />
        #|  <title>Lepus Menu Plugin</title>
        #|  <style>
        #|    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 24px; }
        #|    button { margin-right: 10px; margin-bottom: 8px; padding: 8px 14px; }
        #|    pre { margin-top: 14px; padding: 10px; background: #f5f6f7; border-radius: 8px; min-height: 120px; }
        #|  </style>
        #|</head>
        #|<body>
        #|  <h2>Menu Plugin Example</h2>
        #|  <p>Build and mount an application menu at runtime.</p>
        #|  <div>
        #|    <button onclick="buildMenu()">Build Menu</button>
        #|    <button onclick="clearMenu()">Clear Menu</button>
        #|    <button onclick="drainEvents()">Drain Events</button>
        #|  </div>
        #|  <pre id="out">Waiting...</pre>
        #|  <script>
        #|    const out = document.getElementById("out");
        #|    function setOut(v) {
        #|      out.textContent = typeof v === "string" ? v : JSON.stringify(v, null, 2);
        #|    }
        #|    // IPC 返回值是 JSON 字符串，统一解析成对象
        #|    function parseReply(raw) {
        #|      if (typeof raw !== "string") return raw;
        #|      try { return JSON.parse(raw); } catch(e) { return { ok: false, error: String(raw) }; }
        #|    }
        #|    async function call(name, payload) {
        #|      const fn = window.lepusApi.menu[name];
        #|      const raw = await fn(payload ?? null);
        #|      return parseReply(raw);
        #|    }
        #|    async function buildMenu() {
        #|      try {
        #|        const supported = await call("is_supported");
        #|        if (supported !== true) {
        #|          setOut("menu plugin is only supported on macOS");
        #|          return;
        #|        }
        #|        const result = await call("build_menu", {
        #|          root_id: "root",
        #|          clear_existing: true,
        #|          set_as_app_menu: true,
        #|          menus: [{ id: "root" }],
        #|          submenus: [
        #|            { id: "app-sub", title: "App" },
        #|            { id: "edit-sub", title: "Edit" }
        #|          ],
        #|          items: [
        #|            { id: "hello", text: "Say Hello", accelerator: "CmdOrCtrl+Shift+H" }
        #|          ],
        #|          check_items: [
        #|            { id: "toggle-flag", text: "Enable Flag", checked: true }
        #|          ],
        #|          predefined_items: [
        #|            { id: "copy", kind: "copy" },
        #|            { id: "paste", kind: "paste" },
        #|            { id: "quit", kind: "quit" }
        #|          ],
        #|          links: [
        #|            { parent_id: "root", child_id: "app-sub" },
        #|            { parent_id: "root", child_id: "edit-sub" },
        #|            { parent_id: "app-sub", child_id: "hello" },
        #|            { parent_id: "app-sub", child_id: "toggle-flag" },
        #|            { parent_id: "app-sub", child_id: "quit" },
        #|            { parent_id: "edit-sub", child_id: "copy" },
        #|            { parent_id: "edit-sub", child_id: "paste" }
        #|          ],
        #|          inserts: [],
        #|          toggles: [],
        #|          checks: [],
        #|          texts: [],
        #|          accelerators: []
        #|        });
        #|        setOut(result);
        #|      } catch(e) {
        #|        setOut("ERROR: " + e);
        #|      }
        #|    }
        #|    async function clearMenu() {
        #|      try {
        #|        setOut(await call("clear_app_menu"));
        #|      } catch(e) {
        #|        setOut("ERROR: " + e);
        #|      }
        #|    }
        #|    async function drainEvents() {
        #|      try {
        #|        setOut(await call("drain_events"));
        #|      } catch(e) {
        #|        setOut("ERROR: " + e);
        #|      }
        #|    }
        #|    setInterval(async () => {
        #|      try {
        #|        const events = await call("drain_events");
        #|        if (events && events.ok && events.events && events.events.length > 0) {
        #|          setOut(events);
        #|        }
        #|      } catch(e) {}
        #|    }, 800);
        #|  </script>
        #|</body>
        #|</html>
      ),
    ),
    plugins=[@lepus_plugin_menu.plugin()],
  ).run()
}
