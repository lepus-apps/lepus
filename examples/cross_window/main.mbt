///|
/// Cross-window communication via the App-level event bus.
///
/// The "sender" window emits messages targeted at the "receiver" label; the
/// "receiver" window periodically polls its queue and renders incoming
/// messages. Both windows are children of one App whose main process owns the
/// event bus and routes every `emit`/`poll` command.
async fn main {
  let sender = @lepus.WindowConfig::new(
    label="sender",
    title="Cross-Window — Sender",
    width=640,
    height=420,
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><head><style>
        #|  body { font-family: -apple-system, sans-serif; margin: 0; background: #f5f7fa;
        #|         display: grid; place-items: center; height: 100vh; }
        #|  .card { background: #fff; border-radius: 12px; padding: 32px 44px;
        #|          box-shadow: 0 8px 30px rgba(0,0,0,.08); text-align: center; }
        #|  h1 { margin: 0 0 12px; color: #2c3e50; font-size: 22px; }
        #|  input { padding: 10px; border-radius: 8px; border: 1px solid #ccd7e2; width: 100%; }
        #|  button { margin-top: 14px; padding: 10px 20px; border: none; border-radius: 8px;
        #|           background: #1769ff; color: #fff; font-weight: 600; cursor: pointer; }
        #|  button:hover { background: #0d52d4; }
        #|  #state { margin-top: 12px; color: #7f8c8d; font-size: 13px; }
        #|</style></head>
        #|<body><div class="card">
        #|  <h1>Sender window</h1>
        #|  <input id="text" value="Hello from sender!" />
        #|  <button onclick="send()">Send to receiver</button>
        #|  <div id="state">ready</div>
        #|</div>
        #|<script>
        #|  async function send() {
        #|    const ok = await window.lepusApi.events.emit({
        #|      target: "receiver",
        #|      event: "greet",
        #|      payload: { text: document.getElementById("text").value, at: Date.now() },
        #|    });
        #|    document.getElementById("state").textContent = ok ? "sent" : "failed";
        #|  }
        #|</script></body></html>
      ),
    ),
  )
  let receiver = @lepus.WindowConfig::new(
    label="receiver",
    title="Cross-Window — Receiver",
    width=640,
    height=420,
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><head><style>
        #|  body { font-family: -apple-system, sans-serif; margin: 0; background: #eef2f7;
        #|         display: grid; place-items: center; height: 100vh; }
        #|  .card { background: #fff; border-radius: 12px; padding: 32px 44px;
        #|          box-shadow: 0 8px 30px rgba(0,0,0,.08); text-align: center; min-width: 320px; }
        #|  h1 { margin: 0 0 12px; color: #2c3e50; font-size: 22px; }
        #|  #inbox { text-align: left; white-space: pre-wrap; background: #f0f2f5;
        #|           border-radius: 8px; padding: 12px; color: #2c3e50; font-family: monospace;
        #|           font-size: 13px; min-height: 60px; }
        #|</style></head>
        #|<body><div class="card">
        #|  <h1>Receiver window</h1>
        #|  <div id="inbox">waiting for messages…</div>
        #|</div>
        #|<script>
        #|  const inbox = document.getElementById("inbox");
        #|  let first = true;
        #|  // Push: no polling — the receiver subscribes to events pushed by
        #|  // the main process once the sender emits.
        #|  window.addEventListener("lepus_event", (e) => {
        #|    if (first) { inbox.textContent = ""; first = false; }
        #|    const { event, payload } = e.detail;
        #|    inbox.textContent += `[${event}] ${JSON.stringify(payload)}\n`;
        #|  });
        #|</script></body></html>
      ),
    ),
  )
  @lepus.App::new([sender, receiver]).run()
}
