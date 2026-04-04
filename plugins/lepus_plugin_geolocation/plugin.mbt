///|
pub fn plugin() -> @webview.Plugin {
  @webview.Plugin::new("geolocation", fn(context) {
    @lepus_plugin_support.install_js_api(
      context, "example", "async function(){if(!navigator.geolocation)return{supported:false};const position=await new Promise((resolve,reject)=>navigator.geolocation.getCurrentPosition(resolve,reject,{enableHighAccuracy:false,timeout:5000,maximumAge:0}));return{supported:true,latitude:position.coords.latitude,longitude:position.coords.longitude}}",
    )
  })
}
