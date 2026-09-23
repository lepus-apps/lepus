///|
pub extend BarcodeFormat with @debug.Debug::{to_repr}

///|
pub extend BarcodeFormat with ToJson::{to_json}

///|
pub extend BarcodeFormat with @json.FromJson::{from_json}

///|
pub extend BarcodeFormat with Eq::{not_equal, equal}

///|
pub extend ScanResult with ToJson::{to_json}

///|
pub extend ScanResult with @json.FromJson::{from_json}
