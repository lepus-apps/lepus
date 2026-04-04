///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("clipboard-manager", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){if(!navigator.clipboard)return{supported:false};const text='lepus clipboard example';await navigator.clipboard.writeText(text);return{supported:true,text:await navigator.clipboard.readText()}}",
    )
  })
}
