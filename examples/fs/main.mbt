///|
async fn main {
  @lepus.Window::new(
    title="Lepus Fs Plugin",
    source=@lepus_plugin_support.example_html(
      "fs",
      "Fs Plugin Example",
      content=(
        #|<div style="display:grid;gap:10px;">
        #|  <input id="path" value="/tmp/lepus-fs-example.txt" style="padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|  <textarea id="text" rows="6" style="padding:10px;border-radius:10px;border:1px solid #ccd7e2;">hello from lepus fs plugin</textarea>
        #|  <div style="display:flex;gap:10px;flex-wrap:wrap;">
        #|    <button onclick="writeText()">write_text</button>
        #|    <button onclick="readText()">read_text</button>
        #|    <button onclick="statPath()">stat</button>
        #|    <button onclick="listDir()">readdir(/tmp)</button>
        #|  </div>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|const path = () => document.getElementById("path").value;
        #|const text = () => document.getElementById("text").value;
        #|const show = v => out.textContent = JSON.stringify(v, null, 2);
        #|async function writeText() {
        #|  show(await window.lepusApi.fs.write_text({ path: path(), content: text(), append: false }));
        #|}
        #|async function readText() {
        #|  show(await window.lepusApi.fs.read_text({ path: path() }));
        #|}
        #|async function statPath() {
        #|  show(await window.lepusApi.fs.stat({ path: path() }));
        #|}
        #|async function listDir() {
        #|  show(await window.lepusApi.fs.readdir({ path: "/tmp", include_hidden: false, include_special: false, sort: true }));
        #|}
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_fs.plugin()],
  ).run()
}
