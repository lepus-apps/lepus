///|
async fn main {
  @lepus.Window::new(
    title="Lepus Opener Plugin",
    source=@lepus_plugin_support.example_html(
      "opener",
      "Opener Plugin Example",
      content=(
        #|<input id="target" value="https://www.example.com" style="width:100%;padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|<div style="display:flex;gap:10px;margin-top:10px;">
        #|  <button onclick="openTarget()">open</button>
        #|  <button onclick="supported()">is_supported</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|const target = () => document.getElementById("target").value;
        #|async function openTarget(){ out.textContent = JSON.stringify(await window.lepusApi.opener.open(target()), null, 2); }
        #|async function supported(){ out.textContent = JSON.stringify(await window.lepusApi.opener.is_supported(null), null, 2); }
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_opener.plugin()],
  ).run()
}
