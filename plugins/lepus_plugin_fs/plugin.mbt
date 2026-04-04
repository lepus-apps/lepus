///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("fs", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){const key='lepus.fs.example';localStorage.setItem(key,'hello from lepus fs');const content=localStorage.getItem(key);localStorage.removeItem(key);return{backend:'localStorage',content,removed:localStorage.getItem(key)===null}}",
    )
  })
}
