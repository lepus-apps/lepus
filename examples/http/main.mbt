///|
fn main {
  @lepus.Window::new(
    title="Lepus Http Plugin",
    html=@lepus_plugin_support.example_html(
      "http",
      "Http Plugin Example",
      content=(
        #|<p>Fetch-style API via <code>window.lepusApi.http.fetch</code>.</p>
        #|<div style="display:grid; gap:10px;">
        #|  <label>URL</label>
        #|  <input id="url-input" style="padding:10px 12px; border-radius:12px; border:1px solid #c9d3de;" />
        #|  <label>Method</label>
        #|  <select id="method-input" style="padding:10px 12px; border-radius:12px; border:1px solid #c9d3de;">
        #|    <option>GET</option>
        #|    <option>POST</option>
        #|    <option>PUT</option>
        #|  </select>
        #|  <label>Headers (JSON object)</label>
        #|  <textarea id="headers-input" rows="5" style="padding:10px 12px; border-radius:12px; border:1px solid #c9d3de; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;"></textarea>
        #|  <label>Body (text or JSON string)</label>
        #|  <textarea id="body-input" rows="6" style="padding:10px 12px; border-radius:12px; border:1px solid #c9d3de; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;"></textarea>
        #|</div>
        #|<div style="display:flex; gap:10px; flex-wrap:wrap; margin-top:12px;">
        #|  <button onclick="loadGetPreset()">Load GET Preset</button>
        #|  <button onclick="loadPostPreset()">Load POST Preset</button>
        #|  <button onclick="sendRequest()">Send Request</button>
        #|</div>
        #|<pre id="http-output">HTTP result will appear here</pre>
        #|<script>
        #|  const outputEl = document.getElementById("http-output");
        #|  const urlInput = document.getElementById("url-input");
        #|  const methodInput = document.getElementById("method-input");
        #|  const headersInput = document.getElementById("headers-input");
        #|  const bodyInput = document.getElementById("body-input");
        #|
        #|  function decodeBridgeReply(reply) {
        #|    if (reply && typeof reply === "object") {
        #|      const bridgeStatus = reply.status;
        #|      if (bridgeStatus === "ok") {
        #|        return { ok: true, value: reply.payload };
        #|      }
        #|      if (bridgeStatus === "error") {
        #|        return { ok: false, error: reply.error ?? "Unknown bridge error" };
        #|      }
        #|    }
        #|    return { ok: true, value: reply };
        #|  }
        #|
        #|  async function lepusFetch(url, init) {
        #|    const payload = init ? [url, init] : url;
        #|    const rawReply = await window.lepusApi.http.fetch(payload);
        #|    const decoded = decodeBridgeReply(rawReply);
        #|    if (!decoded.ok) {
        #|      throw new Error(String(decoded.error));
        #|    }
        #|    return decoded.value;
        #|  }
        #|
        #|  function render(title, request, reply) {
        #|    outputEl.innerHTML = [
        #|      title,
        #|      "",
        #|      "Request:",
        #|      JSON.stringify(request, null, 2),
        #|      "",
        #|      "Reply:",
        #|      JSON.stringify(reply, null, 2),
        #|    ].join("<br>");
        #|  }
        #|
        #|  function parseHeaders(text) {
        #|    const trimmed = (text || "").trim();
        #|    if (!trimmed) return {};
        #|    const obj = JSON.parse(trimmed);
        #|    if (!obj || typeof obj !== "object" || Array.isArray(obj)) {
        #|      throw new Error("Headers must be a JSON object");
        #|    }
        #|    const headers = {};
        #|    for (const [k, v] of Object.entries(obj)) {
        #|      headers[String(k)] = String(v);
        #|    }
        #|    return headers;
        #|  }
        #|
        #|  function buildRequest() {
        #|    const url = (urlInput.value || "").trim();
        #|    if (!url) throw new Error("URL is required");
        #|    const method = (methodInput.value || "GET").trim().toUpperCase();
        #|    const headers = parseHeaders(headersInput.value);
        #|    const body = bodyInput.value ?? "";
        #|    const init = { method, headers };
        #|    if (method !== "GET" && body.length > 0) {
        #|      init.body = body;
        #|    }
        #|    return { url, init };
        #|  }
        #|
        #|  async function sendRequest() {
        #|    try {
        #|      const request = buildRequest();
        #|      const reply = await lepusFetch(request.url, request.init);
        #|      const details = {
        #|        ok: reply.ok,
        #|        status: reply.status,
        #|        status_text: reply.status_text,
        #|        error: reply.error,
        #|        headers: reply.headers,
        #|        body_json: reply.body_json,
        #|        body_text: reply.body_text,
        #|      };
        #|      render("Request Completed", request, details);
        #|    } catch (err) {
        #|      render("Request Failed", {}, { error: err?.message ?? String(err) });
        #|    }
        #|  }
        #|
        #|  function loadGetPreset() {
        #|    urlInput.value = "https://httpbin.org/get?from=lepus";
        #|    methodInput.value = "GET";
        #|    headersInput.value = JSON.stringify({ accept: "application/json" }, null, 2);
        #|    bodyInput.value = "";
        #|  }
        #|
        #|  function loadPostPreset() {
        #|    urlInput.value = "https://httpbin.org/post";
        #|    methodInput.value = "POST";
        #|    headersInput.value = JSON.stringify({ "content-type": "application/json" }, null, 2);
        #|    bodyInput.value = JSON.stringify({ source: "lepus", now: Date.now() }, null, 2);
        #|  }
        #|
        #|  loadGetPreset();
        #|</script>
      ),
    ),
    debug=1,
    plugins=[@lepus_plugin_http.plugin()],
  ).run()
}
