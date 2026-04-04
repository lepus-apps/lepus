///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("websocket", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{supported:'WebSocket'in window,states:['CONNECTING','OPEN','CLOSING','CLOSED']}}",
    )
  })
}
