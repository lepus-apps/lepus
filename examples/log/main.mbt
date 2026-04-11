///|
fn main {
  @lepus.Window::new(
    title="Lepus Log Plugin",
    source=@lepus_plugin_support.example_html(
      "log",
      "Log Plugin Example",
      content=(
        #|<input id="msg" value="hello log" style="width:100%;padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|<div style="display:flex;gap:10px;margin-top:10px;flex-wrap:wrap;">
        #|  <button onclick="w('info')">info</button>
        #|  <button onclick="w('warn')">warn</button>
        #|  <button onclick="w('error')">error</button>
        #|  <button onclick="recent()">recent</button>
        #|  <button onclick="clearLog()">clear</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|const msg = () => document.getElementById("msg").value;
        #|async function w(level){ out.textContent = JSON.stringify(await window.lepusApi.log[level](msg()), null, 2); }
        #|async function recent(){ out.textContent = JSON.stringify(await window.lepusApi.log.recent(20), null, 2); }
        #|async function clearLog(){ out.textContent = JSON.stringify(await window.lepusApi.log.clear(null), null, 2); }
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_log.plugin()],
  ).run()
}
