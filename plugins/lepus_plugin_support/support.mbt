///|
pub fn example_html(plugin_name : String, title : String) -> String {
  let plugin_name_js = plugin_name.to_json().stringify()
  (
    #|<!doctype html>
    #|<html>
    #|<head>
    #|  <meta charset="utf-8" />
    $|  <title>\{title}</title>
    #|  <style>
    #|    :root { color-scheme: light; }
    #|    body { margin: 0; font-family: ui-sans-serif, system-ui, sans-serif; background: linear-gradient(135deg, #f3efe3, #dbe7f3); color: #16202a; }
    #|    main { max-width: 880px; margin: 0 auto; min-height: 100vh; display: grid; place-items: center; padding: 24px; }
    #|    section { width: min(100%, 720px); background: rgba(255,255,255,.82); backdrop-filter: blur(14px); border-radius: 24px; box-shadow: 0 20px 60px rgba(22,32,42,.15); padding: 28px; }
    #|    h1 { margin: 0 0 12px; font-size: 32px; }
    #|    p { margin: 0 0 16px; line-height: 1.6; }
    #|    button { border: 0; border-radius: 999px; padding: 12px 18px; font: inherit; background: #16202a; color: white; cursor: pointer; }
    #|    pre { margin: 18px 0 0; padding: 16px; border-radius: 18px; background: #101923; color: #ecf4ff; min-height: 220px; overflow: auto; white-space: pre-wrap; }
    #|  </style>
    #|</head>
    #|<body>
    #|  <main>
    #|    <section>
    $|      <h1>\{title}</h1>
    #|      <p>This example installs the plugin through Lepus register flow and calls <code>example()</code> from the frontend.</p>
    #|      <button id="run">Run Plugin Example</button>
    #|      <pre id="output">Click the button to run the plugin example.</pre>
    #|    </section>
    #|  </main>
    #|  <script>
    #|    const output = document.getElementById('output');
    #|    const run = document.getElementById('run');
    $|    const pluginName = \{plugin_name_js};
    #|    async function execute() {
    #|      output.textContent = 'Running...';
    #|      try {
    #|        const plugin = window.MoonBitPlugins?.[pluginName];
    #|        if (!plugin || typeof plugin.example !== 'function') {
    #|          throw new Error('Plugin example API is not installed');
    #|        }
    #|        const result = await plugin.example();
    #|        output.textContent = JSON.stringify(result, null, 2);
    #|      } catch (error) {
    #|        output.textContent = String(error && error.message ? error.message : error);
    #|      }
    #|    }
    #|    run.addEventListener('click', execute);
    #|  </script>
    #|</body>
    #|</html>
  )
}
