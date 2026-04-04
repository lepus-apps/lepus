///|
pub fn plugin() -> @lepus_runtime_webview.Plugin {
  @lepus_runtime_webview.Plugin::new("single-instance", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){if(!('BroadcastChannel'in window))return{supported:false};const channel=new BroadcastChannel('lepus-single-instance-example');let peers=0;channel.onmessage=()=>{peers=peers+1};channel.postMessage({type:'ping',time:Date.now()});await new Promise(r=>setTimeout(r,120));channel.close();return{supported:true,observedPeers:peers}}",
    )
  })
}
