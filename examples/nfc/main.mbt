///|
fn main {
  @lepus.Window::new(
    title="Lepus Nfc Plugin",
    source=@lepus_plugin_support.example_html(
      "nfc",
      "Nfc Plugin Example",
      content=(
        #|<input id="text" value="hello nfc" style="width:100%;padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|<div style="display:flex;gap:10px;margin-top:10px;">
        #|  <button onclick="encode()">encode</button>
        #|  <button onclick="decode()">decode</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|const text = () => document.getElementById("text").value;
        #|let lastHex = "";
        #|async function encode(){
        #|  const r = await window.lepusApi.nfc.encode({ text: text() });
        #|  lastHex = r.hex || "";
        #|  out.textContent = JSON.stringify(r, null, 2);
        #|}
        #|async function decode(){
        #|  const r = await window.lepusApi.nfc.decode({ hex: lastHex || text() });
        #|  out.textContent = JSON.stringify(r, null, 2);
        #|}
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_nfc.plugin()],
  ).run()
}
