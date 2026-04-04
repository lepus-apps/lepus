///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("shell", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){window.open('https://docs.moonbitlang.com','_blank','noopener');return{opened:true,target:'https://docs.moonbitlang.com'}}",
    )
  })
}
