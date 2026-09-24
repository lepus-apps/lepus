///|
pub extend TitleBarStyle with @debug.Debug::{to_repr}

///|
pub extend TitleBarStyle with Eq::{not_equal, equal}

///|
pub extend TitleBarStyle with Hash::{hash, hash_combine}

///|
pub extend TitleBarStyle with ToJson::{to_json}

///|
pub extend TitleBarStyle with @json.FromJson::{from_json}

///|
pub extend MemoryFile with @debug.Debug::{to_repr}

///|
pub extend MemoryFile with Eq::{not_equal, equal}

///|
pub extend MemoryFile with Hash::{hash, hash_combine}

///|
pub extend MemoryFile with ToJson::{to_json}

///|
pub extend MemoryFile with @json.FromJson::{from_json}

///|
pub extend MemorySource with @debug.Debug::{to_repr}

///|
pub extend MemorySource with Eq::{not_equal, equal}

///|
pub extend MemorySource with Hash::{hash, hash_combine}

///|
pub extend MemorySource with ToJson::{to_json}

///|
pub extend MemorySource with @json.FromJson::{from_json}

///|
pub extend Source with @debug.Debug::{to_repr}

///|
pub extend Source with Eq::{not_equal, equal}

///|
pub extend Source with Hash::{hash, hash_combine}

///|
pub extend Source with ToJson::{to_json}

///|
pub extend Source with @json.FromJson::{from_json}

///|
pub extend WindowConfig with @debug.Debug::{to_repr}

///|
pub extend WindowConfig with Eq::{not_equal, equal}

///|
pub extend WindowConfig with Hash::{hash, hash_combine}

///|
pub extend WindowConfig with ToJson::{to_json}

///|
pub extend WindowConfig with @json.FromJson::{from_json}
