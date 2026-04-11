///|
fn main {
  @lepus.Window::new(
    title="Lepus Autostart Plugin",
    source=@lepus_plugin_support.example_html(
      "autostart",
      "Autostart Plugin Example",
      content=(
        #|<div style="display:grid; gap:10px;">
        #|  <label>App ID</label>
        #|  <input id="app-id" value="lepus-demo" />
        #|  <label>Executable Path</label>
        #|  <input id="exec-path" value="/usr/bin/open" />
        #|  <label>Args</label>
        #|  <input id="exec-args" value="" />
        #|</div>
        #|<div style="display:flex; gap:10px; margin-top:12px;">
        #|  <button onclick="enableAuto()">Enable</button>
        #|  <button onclick="disableAuto()">Disable</button>
        #|  <button onclick="statusAuto()">Status</button>
        #|</div>
        #|<pre id="out">autostart output</pre>
        #|<script>
        #|  const out = document.getElementById("out");
        #|  const appId = () => document.getElementById("app-id").value.trim();
        #|  const execPath = () => document.getElementById("exec-path").value.trim();
        #|  const execArgs = () => document.getElementById("exec-args").value;
        #|  async function enableAuto() {
        #|    out.textContent = JSON.stringify(
        #|      await window.lepusApi.autostart.enable({ app_id: appId(), exec_path: execPath(), args: execArgs() }),
        #|      null,
        #|      2,
        #|    );
        #|  }
        #|  async function disableAuto() {
        #|    out.textContent = JSON.stringify(await window.lepusApi.autostart.disable(appId()), null, 2);
        #|  }
        #|  async function statusAuto() {
        #|    out.textContent = JSON.stringify(await window.lepusApi.autostart.status(appId()), null, 2);
        #|  }
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_autostart.plugin()],
  ).run()
}
