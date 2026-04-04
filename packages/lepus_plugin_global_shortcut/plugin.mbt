///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("global-shortcut", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return new Promise(resolve=>{let matched=false;function handler(event){if(event.ctrlKey&&event.shiftKey&&event.key.toLowerCase()==='k'){matched=true;window.removeEventListener('keydown',handler);resolve({matched:true,combo:'Ctrl+Shift+K'})}}window.addEventListener('keydown',handler);setTimeout(()=>{window.removeEventListener('keydown',handler);resolve({matched,combo:'Ctrl+Shift+K'})},5000)})}",
    )
  })
}
