///|
/// Demonstrates a shared plugin (dialog) installed once at the App level and
/// used independently from every window.
///
/// Each window runs in its own child process and calls `window.lepusApi.dialog`
/// through its child-side proxy. Requests are forwarded to the single main
/// process, whose command router serves all windows and replies to the correct
/// one by window id.
async fn main {
  let main_window = @lepus.WindowConfig::new(
    label="main",
    title="Multi-Window Plugins — Main",
    width=720,
    height=520,
    source=@lepus_plugin_support.example_html(
      "dialog",
      "Multi-Window Dialog — Main",
      content=(
        #|<div style="display:grid; gap:10px;">
        #|  <label>Message</label>
        #|  <textarea id="message" rows="3"
        #|    style="padding:10px; border-radius:10px; border:1px solid #ccd7e2;">Hello from the main window</textarea>
        #|</div>
        #|<div style="display:flex; gap:10px; margin-top:12px;">
        #|  <button onclick="show()">Show in main window</button>
        #|</div>
        #|<pre id="out">dialog output</pre>
        #|<script>
        #|  async function show() {
        #|    const reply = await window.lepusApi.dialog.show({
        #|      title: "Main window dialog",
        #|      message: document.getElementById("message").value,
        #|      level: "Info",
        #|    });
        #|    document.getElementById("out").textContent = JSON.stringify(reply, null, 2);
        #|  }
        #|</script>
      ),
    ),
  )
  let helper_window = @lepus.WindowConfig::new(
    label="helper",
    title="Multi-Window Plugins — Helper",
    width=560,
    height=400,
    source=@lepus_plugin_support.example_html(
      "dialog",
      "Multi-Window Dialog — Helper",
      content=(
        #|<div style="display:grid; gap:10px;">
        #|  <label>Message</label>
        #|  <textarea id="message" rows="3"
        #|    style="padding:10px; border-radius:10px; border:1px solid #ccd7e2;">Hello from the helper window</textarea>
        #|</div>
        #|<div style="display:flex; gap:10px; margin-top:12px;">
        #|  <button onclick="show()">Show in helper window</button>
        #|</div>
        #|<pre id="out">dialog output</pre>
        #|<script>
        #|  async function show() {
        #|    const reply = await window.lepusApi.dialog.show({
        #|      title: "Helper window dialog",
        #|      message: document.getElementById("message").value,
        #|      level: "Info",
        #|    });
        #|    document.getElementById("out").textContent = JSON.stringify(reply, null, 2);
        #|  }
        #|</script>
      ),
    ),
  )
  @lepus.App::new([main_window, helper_window], plugins=[
    @lepus_plugin_dialog.plugin(),
  ]).run()
}
