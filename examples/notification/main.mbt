///|
fn main {
  @lepus.Window::new(
    title="Lepus Notification Plugin",
    source=@lepus_plugin_support.example_html(
      "notification",
      "Notification Plugin Example",
      content=(
        #|<input id="title" value="Lepus Notification" style="width:100%;padding:10px;border-radius:10px;border:1px solid #ccd7e2;" />
        #|<textarea id="body" rows="4" style="width:100%;margin-top:10px;padding:10px;border-radius:10px;border:1px solid #ccd7e2;">Hello from notification plugin</textarea>
        #|<div style="display:flex;gap:10px;margin-top:10px;">
        #|  <button onclick="sendNotice()">send</button>
        #|</div>
        #|<pre id="out">ready</pre>
        #|<script>
        #|const out = document.getElementById("out");
        #|const title = () => document.getElementById("title").value;
        #|const body = () => document.getElementById("body").value;
        #|async function sendNotice(){
        #|  const r = await window.lepusApi.notification.send({ title: title(), body: body() });
        #|  out.textContent = JSON.stringify(r, null, 2);
        #|}
        #|</script>
      ),
    ),
    plugins=[@lepus_plugin_notification.plugin()],
  ).run()
}
