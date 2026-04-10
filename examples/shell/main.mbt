///|
fn main {
  @lepus.Window::new(
    title="Lepus Shell Plugin",
    source=@lepus_plugin_support.example_html(
      "shell",
      "Shell Plugin Example",
      content=(
        #|<p>Run shell commands via <code>window.lepusApi.shell.exec</code>.</p>
        #|<div style="display:flex; gap:10px; flex-wrap:wrap; margin-bottom:12px;">
        #|  <button onclick="runPreset('echo Hello from Lepus')">Echo</button>
        #|  <button onclick="runPreset('pwd')">Pwd</button>
        #|  <button onclick="runPreset('ls -la')">List Files</button>
        #|  <button onclick="runStdinPreset()">Stdin Echo</button>
        #|</div>
        #|<div style="display:grid; gap:10px;">
        #|  <label>Command</label>
        #|  <input id="cmd-input" value="" style="padding:10px 12px; border-radius:12px; border:1px solid #c9d3de;" />
        #|  <label>Args (JSON array)</label>
        #|  <input id="args-input" value="[]" style="padding:10px 12px; border-radius:12px; border:1px solid #c9d3de;" />
        #|  <label>Input Data (stdin)</label>
        #|  <textarea id="stdin-input" rows="6" style="padding:10px 12px; border-radius:12px; border:1px solid #c9d3de; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;"></textarea>
        #|  <button onclick="runCustom()">Run Custom Command</button>
        #|</div>
        #|<pre id="shell-output">Shell output will appear here</pre>
        #|<script>
        #|  const outputEl = document.getElementById("shell-output");
        #|  const cmdInput = document.getElementById("cmd-input");
        #|  const argsInput = document.getElementById("args-input");
        #|  const stdinInput = document.getElementById("stdin-input");
        #|
        #|  function isWindows() {
        #|    return navigator.userAgent.toLowerCase().includes("windows");
        #|  }
        #|
        #|  function decodeBridgeReply(reply) {
        #|    if (reply && typeof reply === "object" && "status" in reply) {
        #|      if (reply.status === "ok") return { ok: true, value: reply.payload };
        #|      return { ok: false, error: reply.error ?? "Unknown bridge error" };
        #|    }
        #|    return { ok: true, value: reply };
        #|  }
        #|
        #|  function renderResult(request, decoded) {
        #|    if (!decoded.ok) {
        #|      outputEl.innerHTML = [
        #|        "Request:",
        #|        JSON.stringify(request, null, 2)),
        #|        "",
        #|        "Error:",
        #|        String(decoded.error),
        #|      ].join("<br>");
        #|      return;
        #|    }
        #|    const value = decoded.value ?? {};
        #|    outputEl.innerHTML = [
        #|      "Request:",
        #|      JSON.stringify(request, null, 2),
        #|      "",
        #|      "Exit Code:",
        #|      String(value.exit_code ?? "<missing>"),
        #|      "",
        #|      "Output:",
        #|      String(value.output ?? ""),
        #|      "",
        #|      "Raw Reply:",
        #|      JSON.stringify(value, null, 2),
        #|    ].join("<br>");
        #|  }
        #|
        #|  async function execCommand(cmd, args, inputData) {
        #|    const request = { cmd, args, input_data: inputData };
        #|    try {
        #|      const rawReply = await window.lepusApi.shell.exec(request);
        #|      renderResult(request, decodeBridgeReply(rawReply));
        #|    } catch (err) {
        #|      renderResult(request, { ok: false, error: err?.message ?? String(err) });
        #|    }
        #|  }
        #|
        #|  async function runPreset(commandLine) {
        #|    if (isWindows()) {
        #|      return execCommand("cmd", ["/C", commandLine], "");
        #|    }
        #|    return execCommand("sh", ["-lc", commandLine], "");
        #|  }
        #|
        #|  async function runStdinPreset() {
        #|    const inputData = "hello\\nfrom\\nstdin\\n";
        #|    stdinInput.value = inputData;
        #|    if (isWindows()) {
        #|      return execCommand("cmd", ["/C", "more"], inputData);
        #|    }
        #|    return execCommand("sh", ["-lc", "cat"], inputData);
        #|  }
        #|
        #|  async function runCustom() {
        #|    const cmd = (cmdInput.value || "").trim();
        #|    if (!cmd) {
        #|      outputEl.textContent = "Please enter a command.";
        #|      return;
        #|    }
        #|    let args = [];
        #|    try {
        #|      const parsed = JSON.parse(argsInput.value || "[]");
        #|      if (!Array.isArray(parsed) || !parsed.every(x => typeof x === "string")) {
        #|        throw new Error("Args must be a JSON array of strings.");
        #|      }
        #|      args = parsed;
        #|    } catch (err) {
        #|      outputEl.textContent = "Invalid args JSON: " + (err?.message ?? String(err));
        #|      return;
        #|    }
        #|    execCommand(cmd, args, stdinInput.value || "");
        #|  }
        #|
        #|  if (isWindows()) {
        #|    cmdInput.value = "cmd";
        #|    argsInput.value = "[\"/C\", \"echo Hello from custom command\"]";
        #|    stdinInput.value = "Type here and click Stdin Echo or Run Custom Command";
        #|  } else {
        #|    cmdInput.value = "sh";
        #|    argsInput.value = "[\"-lc\", \"echo Hello from custom command\"]";
        #|    stdinInput.value = "Type here and click Stdin Echo or Run Custom Command";
        #|  }
        #|</script>
      ),
    ),
    debug=1,
    plugins=[@lepus_plugin_shell.plugin()],
  ).run()
}
