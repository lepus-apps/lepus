///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("websocket", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){return{supported:'WebSocket'in window,states:['CONNECTING','OPEN','CLOSING','CLOSED']}}",
    )
  })
}
