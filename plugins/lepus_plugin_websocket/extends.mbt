///|
pub extend ConnectRequest with ToJson::{to_json}

///|
pub extend ConnectRequest with @json.FromJson::{from_json}

///|
pub extend ConnectReply with ToJson::{to_json}

///|
pub extend ConnectReply with @json.FromJson::{from_json}

///|
pub extend SendRequest with ToJson::{to_json}

///|
pub extend SendRequest with @json.FromJson::{from_json}

///|
pub extend RecvReply with ToJson::{to_json}

///|
pub extend RecvReply with @json.FromJson::{from_json}
