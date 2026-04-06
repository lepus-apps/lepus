///|
fn string_literal(value : String) -> String {
  Json::string(value).stringify()
}

///|
pub fn install_js_initializer(
  context : @webview.PluginContext,
  body : String,
) -> Unit {
  let global_name_js = string_literal(context.global_name())
  let plugin_name_js = string_literal(context.name())
  context.install_script(
    "(function(){const root=window[" +
    global_name_js +
    "];if(!root||typeof root['@@ensurePlugin']!=='function'){return;}const plugin=root['@@ensurePlugin'](" +
    plugin_name_js +
    ");" +
    body +
    "})();",
  )
}

///|
pub fn install_js_api(
  context : @webview.PluginContext,
  api_name : String,
  function_source : String,
) -> Unit {
  let api_name_js = string_literal(api_name)
  install_js_initializer(
    context,
    "plugin[" + api_name_js + "]=" + function_source + ";",
  )
}

///|
pub fn install_rejecting_api(
  context : @webview.PluginContext,
  api_name : String,
  message : String,
) -> Unit {
  install_js_api(
    context,
    api_name,
    "function(){return Promise.reject(new Error(" +
    string_literal(message) +
    "))}",
  )
}

///|
fn async_command_error(api_name : String, err : Error) -> String {
  api_name + ": " + err.to_string()
}

///|
pub fn[Payload : @json.FromJson, Reply : ToJson] command_result_async(
  context : @webview.PluginContext,
  api_name : String,
  callback : async (Payload) -> Result[Reply, String],
) -> Unit {
  context.command_result(api_name, fn(payload) {
    let mut result = Err(api_name + ": internal execution failed")
    @async.run_async_main(() => {
      result = callback(payload) catch {
        err => Err(async_command_error(api_name, err))
      }
    })
    result
  })
}

///|
pub fn[Payload : @json.FromJson, Reply : ToJson] command_async(
  context : @webview.PluginContext,
  api_name : String,
  callback : async (Payload) -> Reply,
) -> Unit {
  command_result_async(context, api_name, payload => Ok(callback(payload)))
}

///|
pub fn example_html(plugin_name : String, title : String) -> String {
  let plugin_name_js = string_literal(plugin_name)
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
