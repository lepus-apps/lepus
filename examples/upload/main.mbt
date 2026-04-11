///|
fn main {
  @lepus.Window::new(
    title="Lepus Upload Plugin",
    source=@lepus_plugin_support.example_html(
      "upload",
      "Upload Plugin Example",
      content=(
        #|<input id="filename" value="demo.txt" style="width:100%;padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|<textarea id="content" rows="6" style="width:100%;margin-top:10px;padding:10px;border-radius:10px;border:1px solid #ccd7e2;">hello upload plugin</textarea>
        #|<div style="display:flex;gap:10px;margin-top:10px;">
        #|  <button onclick="saveText()">save_text</button>
        #|  <button onclick="deleteLast()">delete</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|const filename = () => document.getElementById("filename").value;
        #|const content = () => document.getElementById("content").value;
        #|let lastPath = "";
        #|async function saveText() {
        #|  const r = await window.lepusApi.upload.save_text({ filename: filename(), content: content() });
        #|  lastPath = r.path || "";
        #|  out.textContent = JSON.stringify(r, null, 2);
        #|}
        #|async function deleteLast() {
        #|  if (!lastPath) { out.textContent = "no file path"; return; }
        #|  out.textContent = JSON.stringify(await window.lepusApi.upload.delete(lastPath), null, 2);
        #|}
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_upload.plugin()],
  ).run()
}
