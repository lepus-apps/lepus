///|
pub extend NotifyRequest with ToJson::{to_json}

///|
pub extend NotifyRequest with @json.FromJson::{from_json}

///|
pub extend NotifyReply with ToJson::{to_json}

///|
pub extend NotifyReply with @json.FromJson::{from_json}
