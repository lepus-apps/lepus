///|
async fn main {
  @lepus.Window::new(
    title="Lepus Dialog Plugin",
    source=@lepus_plugin_support.example_html(
      "dialog",
      "Dialog Plugin Example",
      content=(
        #|<div style="display:grid; gap:10px;">
        #|  <label>Title</label>
        #|  <input id="title" value="Lepus Dialog" style="padding:10px; border-radius:10px; border:1px solid #ccd7e2;" />
        #|  <label>Message</label>
        #|  <textarea id="message" rows="4" style="padding:10px; border-radius:10px; border:1px solid #ccd7e2;">Hello from dialog plugin</textarea>
        #|  <label>Level</label>
        #|  <select id="level" style="padding:10px; border-radius:10px; border:1px solid #ccd7e2;">
        #|    <option>Info</option>
        #|    <option>Warning</option>
        #|    <option>Error</option>
        #|  </select>
        #|</div>
        #|<div style="display:flex; gap:10px; margin-top:12px;">
        #|  <button onclick="showDialog()">Show Dialog</button>
        #|  <button onclick="confirmDialog()">Confirm Dialog</button>
        #|</div>
        #|<pre id="dialog-out">dialog output</pre>
        #|<script>
        #|  const out = document.getElementById("dialog-out");
        #|  const title = () => document.getElementById("title").value;
        #|  const message = () => document.getElementById("message").value;
        #|  const level = () => document.getElementById("level").value;
        #|  async function showDialog() {
        #|    const reply = await window.lepusApi.dialog.show({
        #|      title: title(),
        #|      message: message(),
        #|      level: level(),
        #|    });
        #|    out.textContent = JSON.stringify(reply, null, 2);
        #|  }
        #|  async function confirmDialog() {
        #|    const reply = await window.lepusApi.dialog.confirm({
        #|      title: title(),
        #|      message: message(),
        #|      default_ok: true,
        #|    });
        #|    out.textContent = JSON.stringify(reply, null, 2);
        #|  }
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_dialog.plugin()],
  ).run()
}
