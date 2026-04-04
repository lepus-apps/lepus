///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("notification", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){if(!('Notification'in window))return{supported:false};const permission=await Notification.requestPermission();if(permission==='granted')new Notification('Lepus notification example',{body:'This came from the notification plugin example.'});return{supported:true,permission}}",
    )
  })
}
