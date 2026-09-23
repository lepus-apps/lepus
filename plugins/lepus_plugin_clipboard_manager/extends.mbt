///|
pub extend ClipboardError with @debug.Debug::{to_repr}

///|
pub extend ClipboardError with Eq::{not_equal, equal}

///|
pub extend ClipboardTextReply with ToJson::{to_json}

///|
pub extend ClipboardTextReply with @json.FromJson::{from_json}

///|
pub extend ClipboardWriteRequest with ToJson::{to_json}

///|
pub extend ClipboardWriteRequest with @json.FromJson::{from_json}

///|
pub extend ClipboardWriteReply with ToJson::{to_json}

///|
pub extend ClipboardWriteReply with @json.FromJson::{from_json}

///|
pub extend ClipboardBoolReply with ToJson::{to_json}

///|
pub extend ClipboardBoolReply with @json.FromJson::{from_json}

///|
pub extend ClipboardExampleReply with ToJson::{to_json}

///|
pub extend ClipboardExampleReply with @json.FromJson::{from_json}
