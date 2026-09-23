///|
pub extend CommandResponse with Eq::{not_equal, equal}

///|
pub extend ProcessCommandRequest with ToJson::{to_json}

///|
pub extend ProcessCommandRequest with @json.FromJson::{from_json}

///|
pub extend ProcessCommandResponse with ToJson::{to_json}

///|
pub extend ProcessCommandResponse with @json.FromJson::{from_json}

///|
pub extend ProcessCommandReplyForTest with @json.FromJson::{from_json}

///|
pub extend WindowState with Eq::{not_equal, equal}

///|
pub extend ProcessType with Eq::{not_equal, equal}

///|
pub extend IpcMessageType with Eq::{not_equal, equal}

///|
pub extend TitleBarStyle with @debug.Debug::{to_repr}

///|
pub extend TitleBarStyle with Eq::{not_equal, equal}
