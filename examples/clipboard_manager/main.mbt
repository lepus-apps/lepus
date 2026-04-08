///|
fn main {
  @lepus.Window::new(
    title="Lepus Clipboard Manager Plugin",
    html=@lepus_plugin_support.example_html(
      "clipboard_manager",
      "Clipboard Manager Plugin Example",
      content=(
        #|<button onclick="write_text('Hello, world!')">Write "Hello, world!" to Clipboard</button>
        #|<button onclick="write_text('Lepus')">Write "Lepus" to Clipboard</button>
        #|<button onclick="window.lepusApi.clipboard_manager.clear()">Clear Clipboard</button>
        #|<pre id="clipboard-content">Clipboard content will appear here</pre>
        #|<script>
        #|  const contentElement = document.getElementById("clipboard-content");
        #|  async function write_text(content) {
        #|    const result = await window.lepusApi.clipboard_manager.write_text(content);
        #|    contentElement.textContent = content;
        #|    if (!result.success) {
        #|      alert("Failed to write to clipboard: " + result.error);
        #|    }
        #|  }
        #|  async function updateClipboardContent() {
        #|    const result = await window.lepusApi.clipboard_manager.read_text();
        #|    if (result.supported) {
        #|      contentElement.textContent = result.text ?? "Clipboard is empty";
        #|    } else {
        #|      contentElement.textContent = "Clipboard API not supported: " + result.error;
        #|    }
        #|  }
        #|  setInterval(updateClipboardContent, 1000);
        #|  updateClipboardContent();
        #|</script>
      ),
    ),
    debug=1,
    plugins=[@lepus_plugin_clipboard_manager.plugin()],
  ).run()
}
