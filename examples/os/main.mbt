///|
async fn main {
  @lepus.Window::new(
    title="Lepus Os Plugin",
    source=@lepus_plugin_support.example_html(
      "os",
      "Os Plugin Example",
      content=(
        #|<div style="display:flex;gap:10px;">
        #|  <button onclick="run('os')">os</button>
        #|  <button onclick="run('arch')">arch</button>
        #|  <button onclick="run('info')">info</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|async function run(name){
        #|  out.textContent = JSON.stringify(await window.lepusApi.os[name](null), null, 2);
        #|}
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_os.plugin()],
  ).run()
}
