///|
pub extend DialogLevel with @debug.Debug::{to_repr}

///|
pub extend DialogLevel with ToJson::{to_json}

///|
pub extend DialogLevel with @json.FromJson::{from_json}

///|
pub extend DialogLevel with Eq::{not_equal, equal}

///|
pub extend DialogRequest with ToJson::{to_json}

///|
pub extend DialogRequest with @json.FromJson::{from_json}

///|
pub extend ConfirmRequest with ToJson::{to_json}

///|
pub extend ConfirmRequest with @json.FromJson::{from_json}

///|
pub extend DialogReply with ToJson::{to_json}

///|
pub extend DialogReply with @json.FromJson::{from_json}

///|
pub extend ConfirmReply with ToJson::{to_json}

///|
pub extend ConfirmReply with @json.FromJson::{from_json}
