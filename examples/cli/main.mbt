///|
async fn main {
  @lepus.Window::new(
    title="Lepus Cli Plugin",
    source=@lepus_plugin_support.example_html(
      "cli",
      "Cli Plugin Example",
      content=(
        #|<div style="display:flex;gap:10px;flex-wrap:wrap;">
        #|  <button onclick="run('args')">args</button>
        #|  <button onclick="run('cwd')">cwd</button>
        #|  <button onclick="run('info')">info</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|async function run(cmd){
        #|  out.textContent = JSON.stringify(await window.lepusApi.cli[cmd](null), null, 2);
        #|}
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_cli.plugin()],
  ).run()
}
