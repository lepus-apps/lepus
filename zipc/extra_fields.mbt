// ZIP extra fields support
// Extra fields provide extensible metadata for ZIP entries

// Extra field structure

///|
pub struct ExtraField {
  header_id : UInt16 // 2 bytes - identifies the field type
  data_size : Int // 2 bytes - size of data
  data : StringView // Variable length data
}

// Common extra field header IDs

///|
pub let zip64_extra_field_id : UInt16 = 0x0001 // ZIP64 extended information

///|
pub let ntfs_extra_field_id : UInt16 = 0x000a // NTFS timestamps

///|
pub let unix_extra_field_id : UInt16 = 0x000d // Unix timestamps

///|
pub let info_zip_unix_id : UInt16 = 0x5455 // Info-ZIP Unix timestamp

///|
pub let unicode_path_id : UInt16 = 0x7075 // Unicode path extra field

///|
pub let unicode_comment_id : UInt16 = 0x6375 // Unicode comment extra field

// Parse extra fields from binary data

///|
pub fn parse_extra_fields(data : String) -> Array[ExtraField] {
  let fields : Array[ExtraField] = []
  let mut offset = 0
  while offset + 4 <= data.length() {
    // Read header ID (2 bytes, little-endian)
    let header_id = read_u16_le_extra(data, offset)
    offset = offset + 2

    // Read data size (2 bytes, little-endian)
    let data_size = read_u16_le_extra(data, offset).to_int()
    offset = offset + 2

    // Read data
    if offset + data_size <= data.length() {
      let field_data = data[offset:offset + data_size]
      fields.push({ header_id, data_size, data: field_data })
      offset = offset + data_size
    } else {
      // Truncated field, stop parsing
      break
    }
  }
  fields
}

// Serialize extra fields to binary data

///|
pub fn serialize_extra_fields(fields : Array[ExtraField]) -> StringView {
  let mut result : StringView = ""
  for i = 0; i < fields.length(); i = i + 1 {
    let field = fields[i]

    // Write header ID (2 bytes, little-endian)
    result = result + write_u16_le_extra(field.header_id)

    // Write data size (2 bytes, little-endian)
    result = result + write_u16_le_extra(field.data.length().to_uint16())

    // Write data
    result = result + field.data
  }
  result
}

// Create Unix timestamp extra field (Info-ZIP format)

///|
pub fn create_unix_timestamp_field(
  modification_time : Int,
  access_time : Int?,
  creation_time : Int?,
) -> ExtraField {
  let mut data = ""

  // Flags byte (which timestamps are present)
  let mut flags = 1 // Modification time is always present
  match access_time {
    Some(_) => flags = flags | 2
    None => ()
  }
  match creation_time {
    Some(_) => flags = flags | 4
    None => ()
  }
  data = data + flags.unsafe_to_char().to_string()

  // Modification time (4 bytes, little-endian)
  data = data + write_u32_le_extra(modification_time)

  // Access time (if present)
  match access_time {
    Some(time) => data = data + write_u32_le_extra(time)
    None => ()
  }

  // Creation time (if present)
  match creation_time {
    Some(time) => data = data + write_u32_le_extra(time)
    None => ()
  }
  { header_id: info_zip_unix_id, data_size: data.length(), data }
}

// Parse Unix timestamp extra field

///|
pub fn parse_unix_timestamp_field(field : ExtraField) -> (UInt, UInt?, UInt?)? {
  if field.header_id != info_zip_unix_id || field.data.length() < 5 {
    return None
  }
  let flags = field.data[0]
  let mut offset = 1

  // Modification time (always present)
  if offset + 4 > field.data.length() {
    return None
  }
  let modification_time = read_u32_le_extra(field.data, offset)
  offset = offset + 4

  // Access time (if flag bit 1 is set)
  let access_time = if (flags & 2) != 0 {
    if offset + 4 > field.data.length() {
      None
    } else {
      let time = read_u32_le_extra(field.data, offset)
      offset = offset + 4
      Some(time)
    }
  } else {
    None
  }

  // Creation time (if flag bit 2 is set)
  let creation_time = if (flags & 4) != 0 {
    if offset + 4 > field.data.length() {
      None
    } else {
      let time = read_u32_le_extra(field.data, offset)
      Some(time)
    }
  } else {
    None
  }
  Some((modification_time, access_time, creation_time))
}

// Create Unicode path extra field

///|
pub fn create_unicode_path_field(
  unicode_path : String,
  crc32 : Int,
) -> ExtraField {
  let mut data = ""

  // Version (1 byte)
  data = data + "\u{01}"

  // CRC-32 of original path (4 bytes, little-endian)
  data = data + write_u32_le_extra(crc32)

  // Unicode path (UTF-8)
  data = data + unicode_path
  { header_id: unicode_path_id, data_size: data.length(), data }
}

// Parse Unicode path extra field

///|
pub fn parse_unicode_path_field(field : ExtraField) -> (StringView, UInt)? {
  if field.header_id != unicode_path_id || field.data.length() < 6 {
    return None
  }
  let version = field.data[0]
  if version != 1 {
    return None // Unsupported version
  }
  let crc32 = read_u32_le_extra(field.data, 1)
  let unicode_path = field.data[5:field.data.length()]
  Some((unicode_path, crc32))
}

// Find extra field by header ID

///|
pub fn find_extra_field(
  fields : Array[ExtraField],
  header_id : UInt16,
) -> ExtraField? {
  for i = 0; i < fields.length(); i = i + 1 {
    let field = fields[i]
    if field.header_id == header_id {
      return Some(field)
    }
  }
  None
}

// Remove extra field by header ID

///|
pub fn remove_extra_field(
  fields : Array[ExtraField],
  header_id : UInt16,
) -> Array[ExtraField] {
  let result : Array[ExtraField] = []
  for i = 0; i < fields.length(); i = i + 1 {
    let field = fields[i]
    if field.header_id != header_id {
      result.push(field)
    }
  }
  result
}

// Add or replace extra field

///|
pub fn set_extra_field(
  fields : Array[ExtraField],
  new_field : ExtraField,
) -> Array[ExtraField] {
  let result = remove_extra_field(fields, new_field.header_id)
  result.push(new_field)
  result
}

// Calculate total size of extra fields

///|
pub fn extra_fields_size(fields : Array[ExtraField]) -> Int {
  let mut total = 0
  for i = 0; i < fields.length(); i = i + 1 {
    let field = fields[i]
    total = total + 4 + field.data.length() // 4 bytes header + data
  }
  total
}

// Validate extra field

///|
pub fn validate_extra_field(field : ExtraField) -> Bool {
  // Check that data size matches actual data length
  field.data_size == field.data.length() &&
  // Check reasonable size limits
  field.data.length() <= 65535 &&
  // Header ID should be non-zero
  field.header_id > 0
}

// Helper functions for binary I/O (extra fields version to avoid conflicts)

///|
pub fn read_u16_le_extra(data : String, offset : Int) -> UInt16 {
  if offset + 1 >= data.length() {
    return 0
  }
  let b0 = data[offset]
  let b1 = data[offset + 1]
  b0 + (b1 << 8)
}

///|
pub fn write_u16_le_extra(value : UInt16) -> String {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  b0.unsafe_to_char().to_string() + b1.unsafe_to_char().to_string()
}

///|
pub fn read_u32_le_extra(data : StringView, offset : Int) -> UInt {
  if offset + 3 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_uint()
  let b1 = data[offset + 1].to_uint()
  let b2 = data[offset + 2].to_uint()
  let b3 = data[offset + 3].to_uint()
  b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
}

///|
pub fn write_u32_le_extra(value : Int) -> String {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  let b2 = (value >> 16) & 0xff
  let b3 = (value >> 24) & 0xff
  b0.unsafe_to_char().to_string() +
  b1.unsafe_to_char().to_string() +
  b2.unsafe_to_char().to_string() +
  b3.unsafe_to_char().to_string()
}
