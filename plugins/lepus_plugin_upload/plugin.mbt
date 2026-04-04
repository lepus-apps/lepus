///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("upload", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){const form=new FormData();form.set('message','hello from lepus upload');return{supported:true,fields:Array.from(form.keys())}}",
    )
  })
}
