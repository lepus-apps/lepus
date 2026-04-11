///|
fn main {
  @lepus.Window::new(
    title="Lepus Store Plugin",
    source=@lepus_plugin_support.example_html(
      "store",
      "Store Plugin Example",
      content=(
        #|<input id="key" value="foo" style="width:100%;padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|<input id="value" value="bar" style="width:100%;margin-top:10px;padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|<div style="display:flex;gap:10px;margin-top:10px;flex-wrap:wrap;">
        #|  <button onclick="setItem()">set</button>
        #|  <button onclick="getItem()">get</button>
        #|  <button onclick="removeItem()">remove</button>
        #|  <button onclick="dumpAll()">dump</button>
        #|  <button onclick="clearAll()">clear</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|const key = () => document.getElementById("key").value;
        #|const value = () => document.getElementById("value").value;
        #|async function setItem(){ out.textContent = JSON.stringify(await window.lepusApi.store.set({ key: key(), value: value() }), null, 2); }
        #|async function getItem(){ out.textContent = JSON.stringify(await window.lepusApi.store.get(key()), null, 2); }
        #|async function removeItem(){ out.textContent = JSON.stringify(await window.lepusApi.store.remove(key()), null, 2); }
        #|async function dumpAll(){ out.textContent = JSON.stringify(await window.lepusApi.store.dump(null), null, 2); }
        #|async function clearAll(){ out.textContent = JSON.stringify(await window.lepusApi.store.clear(null), null, 2); }
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_store.plugin()],
  ).run()
}
