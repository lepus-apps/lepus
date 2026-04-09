// Gzip format support - deflate with gzip headers and CRC-32
// RFC 1952: GZIP file format specification

// Gzip compressed data structure

///|
pub struct GzipData {
  compressed_bytes : Bytes
  original_size : Int
  crc32_checksum : @crc32.Crc32
  filename : String?
  comment : String?
  modification_time : Int // Unix timestamp
}

// Gzip header flags

///|
let _ftext_flag : Int = 0x01 // File is probably ASCII text

///|
let fhcrc_flag : Int = 0x02 // Header CRC present

///|
let fextra_flag : Int = 0x04 // Extra fields present

///|
let fname_flag : Int = 0x08 // Original filename present

///|
let fcomment_flag : Int = 0x10 // Comment present

// Compress data using gzip format (deflate + gzip headers + CRC-32)

///|
pub fn gzip_compress_bytes(
  data : Bytes,
  level : Level,
  filename : String?,
  comment : String?,
  modification_time : Int,
) -> GzipData {
  // Calculate CRC-32 of original data
  let crc = @crc32.bytes(data)

  // Compress using deflate
  match deflate_compress(data, level) {
    deflate_data => {
      // Build gzip header
      let mut header = Bytes::from_array([])

      // Magic number (2 bytes): 0x1f, 0x8b
      header = header + Bytes::from_array([0x1f, 0x8b])

      // Compression method (1 byte): 8 for deflate
      header = header + Bytes::from_array([0x08])

      // Flags (1 byte)
      let mut flags = 0
      match filename {
        Some(_) => flags = flags | fname_flag
        None => ()
      }
      match comment {
        Some(_) => flags = flags | fcomment_flag
        None => ()
      }
      header = header + Bytes::from_array([flags.to_byte()])

      // Modification time (4 bytes, little-endian)
      header = header + write_u32_le_bytes(modification_time)

      // Extra flags (1 byte)
      let extra_flags = match level {
        Level::Best => 2 // Maximum compression
        Level::Fast => 4 // Fastest compression
        _ => 0 // Default
      }
      header = header + Bytes::from_array([extra_flags.to_byte()])

      // Operating system (1 byte): 255 for unknown
      header = header + Bytes::from_array([0xff])

      // Optional filename (null-terminated)
      match filename {
        Some(name) =>
          header = header + @utf8.encode(name) + Bytes::from_array([0x00])
        None => ()
      }

      // Optional comment (null-terminated)
      match comment {
        Some(comm) =>
          header = header + @utf8.encode(comm) + Bytes::from_array([0x00])
        None => ()
      }

      // Build trailer: CRC-32 (4 bytes) + original size (4 bytes), both little-endian
      let trailer = write_u32_le_bytes(crc.0.to_int()) +
        write_u32_le_bytes(data.length())

      // Combine header + deflate data + trailer
      let gzip_bytes = header + deflate_data.compressed_bytes + trailer
      {
        compressed_bytes: gzip_bytes,
        original_size: data.length(),
        crc32_checksum: crc,
        filename,
        comment,
        modification_time,
      }
    }
  }
}

// Decompress gzip data

///|
pub fn gzip_decompress_bytes(gzip_data : GzipData) -> Bytes raise {
  let data = gzip_data.compressed_bytes
  if data.length() < 18 { // Minimum: 10-byte header + 8-byte trailer
    fail("Gzip data too short (minimum 18 bytes)")
  }

  // Parse gzip header
  let mut offset = 0

  // Check magic number
  if data[offset].to_int() != 0x1f || data[offset + 1].to_int() != 0x8b {
    fail("Invalid gzip magic number")
  }
  offset = offset + 2

  // Check compression method
  if data[offset].to_int() != 8 {
    fail("Unsupported compression method: " + data[offset].to_int().to_string())
  }
  offset = offset + 1

  // Read flags
  let flags = data[offset].to_int()
  offset = offset + 1

  // Skip modification time (4 bytes)
  offset = offset + 4

  // Skip extra flags (1 byte)
  offset = offset + 1

  // Skip operating system (1 byte)
  offset = offset + 1

  // Skip extra fields if present
  if (flags & fextra_flag) != 0 {
    if offset + 2 > data.length() {
      fail("Truncated gzip extra fields")
    }
    let extra_len = gzip_read_u16_le_bytes(data, offset)
    offset = offset + 2 + extra_len
    if offset > data.length() {
      fail("Truncated gzip extra fields data")
    }
  }

  // Skip filename if present
  if (flags & fname_flag) != 0 {
    while offset < data.length() && data[offset].to_int() != 0 {
      offset = offset + 1
    }
    if offset >= data.length() {
      fail("Truncated gzip filename")
    }
    offset = offset + 1 // Skip null terminator
  }

  // Skip comment if present
  if (flags & fcomment_flag) != 0 {
    while offset < data.length() && data[offset].to_int() != 0 {
      offset = offset + 1
    }
    if offset >= data.length() {
      fail("Truncated gzip comment")
    }
    offset = offset + 1 // Skip null terminator
  }

  // Skip header CRC if present
  if (flags & fhcrc_flag) != 0 {
    offset = offset + 2
    if offset > data.length() {
      fail("Truncated gzip header CRC")
    }
  }

  // Extract deflate data (everything except trailer)
  if offset + 8 > data.length() {
    fail("Truncated gzip trailer")
  }
  let deflate_end = data.length() - 8
  let deflate_bytes = data[offset:deflate_end].to_bytes()

  // Extract trailer: CRC-32 and original size
  let expected_crc = read_u32_le_bytes(data, deflate_end).to_int64()
  let expected_size = read_u32_le_bytes(data, deflate_end + 4)

  // Decompress deflate data
  let _deflate_data : DeflateData = {
    compressed_bytes: deflate_bytes,
    original_size: expected_size,
    adler32_checksum: 0L, // Gzip uses CRC-32, not Adler-32
  }

  // Use bytes-based deflate decompression to avoid String conversion corruption
  let decompressed_bytes = decompress_deflate_blocks_bytes(deflate_bytes)
  // Verify size
  if decompressed_bytes.length() != expected_size {
    fail(
      "Gzip size mismatch: expected " +
      expected_size.to_string() +
      ", got " +
      decompressed_bytes.length().to_string(),
    )
  }

  // Verify CRC-32 checksum
  let computed_crc = @crc32.bytes(decompressed_bytes)
  if computed_crc != expected_crc {
    fail("Gzip CRC-32 checksum mismatch")
  }
  decompressed_bytes
}

// Helper function to write 32-bit little-endian integer as bytes

///|
fn write_u32_le_bytes(value : Int) -> Bytes {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  let b2 = (value >> 16) & 0xff
  let b3 = (value >> 24) & 0xff
  Bytes::from_array([b0.to_byte(), b1.to_byte(), b2.to_byte(), b3.to_byte()])
}

// Helper function to read 16-bit little-endian integer from bytes

///|
fn gzip_read_u16_le_bytes(data : Bytes, offset : Int) -> Int {
  if offset + 1 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  b0 + (b1 << 8)
}

// Helper function to read 32-bit little-endian integer from bytes

///|
fn read_u32_le_bytes(data : Bytes, offset : Int) -> Int {
  if offset + 3 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
}

// Bytes-based gzip functions (more efficient for binary data)

///|
pub fn gzip_of_bytes(
  data : Bytes,
  level : Level,
  filename : String?,
  comment : String?,
) -> Bytes {
  // Use the modern bytes-based implementation directly
  match gzip_compress_bytes(data, level, filename, comment, 0) {
    gzip_data => gzip_data.compressed_bytes
  }
}

///|
pub fn gzip_to_bytes(compressed_data : Bytes) -> Bytes raise {
  // Use the modern bytes-based implementation directly
  let gzip_data : GzipData = {
    compressed_bytes: compressed_data,
    original_size: 0, // Will be read from trailer
    crc32_checksum: @crc32.Crc32(0L), // Will be read from trailer
    filename: None,
    comment: None,
    modification_time: 0,
  }
  gzip_decompress_bytes(gzip_data)
}

// Extract metadata from gzip file

///|
pub fn gzip_extract_metadata_bytes(
  compressed_data : Bytes,
) -> Result[GzipData, String] {
  if compressed_data.length() < 18 {
    return Err("Gzip data too short")
  }
  let mut offset = 0

  // Check magic number
  if compressed_data[offset].to_int() != 0x1f ||
    compressed_data[offset + 1].to_int() != 0x8b {
    return Err("Invalid gzip magic number")
  }
  offset = offset + 2

  // Skip compression method
  offset = offset + 1

  // Read flags
  let flags = compressed_data[offset].to_int()
  offset = offset + 1

  // Read modification time
  let mtime = read_u32_le_bytes(compressed_data, offset)
  offset = offset + 4

  // Skip extra flags and OS
  offset = offset + 2

  // Skip extra fields if present
  if (flags & fextra_flag) != 0 {
    let extra_len = gzip_read_u16_le_bytes(compressed_data, offset)
    offset = offset + 2 + extra_len
  }

  // Read filename if present
  let mut filename : String? = None
  if (flags & fname_flag) != 0 {
    let start = offset
    while offset < compressed_data.length() &&
          compressed_data[offset].to_int() != 0 {
      offset = offset + 1
    }
    if offset < compressed_data.length() {
      filename = Some(compressed_data[start:offset].to_bytes().to_string())
      offset = offset + 1
    }
  }

  // Read comment if present
  let mut comment : String? = None
  if (flags & fcomment_flag) != 0 {
    let start = offset
    while offset < compressed_data.length() &&
          compressed_data[offset].to_int() != 0 {
      offset = offset + 1
    }
    if offset < compressed_data.length() {
      comment = Some(compressed_data[start:offset].to_bytes().to_string())
      offset = offset + 1
    }
  }

  // Read trailer
  let trailer_offset = compressed_data.length() - 8
  let crc = read_u32_le_bytes(compressed_data, trailer_offset).to_int64()
  let original_size = read_u32_le_bytes(compressed_data, trailer_offset + 4)
  Ok({
    compressed_bytes: compressed_data,
    original_size,
    crc32_checksum: crc,
    filename,
    comment,
    modification_time: mtime,
  })
}
