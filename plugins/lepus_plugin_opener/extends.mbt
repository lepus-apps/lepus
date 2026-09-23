///|
pub extend OpenerError with Eq::{not_equal, equal}

///|
pub extend OpenerError with @debug.Debug::{to_repr}

///|
pub extend OpenReply with ToJson::{to_json}

///|
pub extend OpenReply with @json.FromJson::{from_json}
