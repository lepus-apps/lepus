// Zlib format support - deflate with headers and checksums
// RFC 1950: ZLIB Compressed Data Format Specification

// Zlib compressed data structure

///|
pub struct ZlibData {
  compressed_bytes : Bytes
  original_size : Int
  adler32_checksum : @adler32.Adler32
}

// Compress data using zlib format (deflate + headers + checksum)

///|
pub fn zlib_compress_bytes(data : Bytes, level : Level) -> ZlibData {
  // Calculate Adler-32 of original data
  let adler = @adler32.bytes(data)

  // Compress using deflate
  let deflate_data = deflate_compress(data, level)
  // Create zlib header (2 bytes)
  let compression_method = 8 // Deflate
  let compression_info = 7 // 32K window size
  let cmf = compression_method | (compression_info << 4)
  let fcheck = 0 // Will be calculated
  let fdict = 0 // No preset dictionary
  let flevel = match level {
    Level::None => 0 // Fastest
    Level::Fast => 1 // Fast
    Level::Default => 2 // Default
    Level::Best => 3 // Maximum compression
  }
  let flg = (flevel << 6) | (fdict << 5) | fcheck

  // Calculate FCHECK to make (CMF*256 + FLG) divisible by 31
  let header_base = cmf * 256 + flg
  let fcheck_calculated = (31 - header_base % 31) % 31
  let flg_final = (flg & 0xe0) | fcheck_calculated

  // Build zlib data: header + deflate data + adler32
  let header = write_u16_be_bytes(cmf * 256 + flg_final)
  let adler_bytes = write_u32_be_bytes(adler.0.to_int())
  let zlib_bytes = header + deflate_data.compressed_bytes + adler_bytes
  {
    compressed_bytes: zlib_bytes,
    original_size: data.length(),
    adler32_checksum: adler,
  }
}

// Decompress zlib data

///|
pub fn zlib_decompress_bytes(zlib_data : ZlibData) -> Bytes raise {
  let data = zlib_data.compressed_bytes
  if data.length() < 6 {
    fail("Zlib data too short (minimum 6 bytes)")
  }

  // Parse zlib header (2 bytes)
  let cmf = data[0].to_int()
  let flg = data[1].to_int()

  // Verify header checksum
  let header_check = (cmf * 256 + flg) % 31
  if header_check != 0 {
    fail("Invalid zlib header checksum")
  }

  // Extract compression method and info
  let compression_method = cmf & 0x0f
  let compression_info = (cmf >> 4) & 0x0f
  if compression_method != 8 {
    fail("Unsupported compression method: " + compression_method.to_string())
  }
  if compression_info > 7 {
    fail("Invalid compression info: " + compression_info.to_string())
  }

  // Check for preset dictionary (not supported)
  let fdict = (flg >> 5) & 1
  if fdict != 0 {
    fail("Preset dictionaries not supported")
  }

  // Extract deflate data (everything except header and trailing checksum)
  let deflate_start = 2
  let deflate_end = data.length() - 4
  let deflate_bytes = data[deflate_start:deflate_end].to_bytes()

  // Extract Adler-32 checksum (last 4 bytes, big-endian)
  let expected_adler = read_u32_be_bytes(data, deflate_end).to_int64()

  // Decompress deflate data
  let deflate_data : DeflateData = {
    compressed_bytes: deflate_bytes,
    original_size: zlib_data.original_size,
    adler32_checksum: expected_adler,
  }
  let decompressed = deflate_decompress(deflate_data)
  // Verify Adler-32 checksum
  let computed_adler = @adler32.bytes(decompressed)
  if computed_adler == expected_adler {
    decompressed
  } else {
    fail("Adler-32 checksum mismatch in zlib data")
  }
}

// Helper function to write 16-bit big-endian integer as bytes

///|
fn write_u16_be_bytes(value : Int) -> Bytes {
  let b0 = (value >> 8) & 0xff
  let b1 = value & 0xff
  Bytes::from_array([b0.to_byte(), b1.to_byte()])
}

// Helper function to write 32-bit big-endian integer as bytes

///|
fn write_u32_be_bytes(value : Int) -> Bytes {
  let b0 = (value >> 24) & 0xff
  let b1 = (value >> 16) & 0xff
  let b2 = (value >> 8) & 0xff
  let b3 = value & 0xff
  Bytes::from_array([b0.to_byte(), b1.to_byte(), b2.to_byte(), b3.to_byte()])
}

// Helper function to read 32-bit big-endian integer from bytes

///|
fn read_u32_be_bytes(data : Bytes, offset : Int) -> Int {
  if offset + 3 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  (b0 << 24) + (b1 << 16) + (b2 << 8) + b3
}

// Bytes-based zlib functions (more efficient for binary data)

///|
pub fn zlib_of_bytes(data : Bytes, level : Level) -> Bytes {
  // Use the modern bytes-based implementation directly
  let zlib_data = zlib_compress_bytes(data, level)
  zlib_data.compressed_bytes
}

///|
pub fn zlib_to_bytes(
  compressed_data : Bytes,
  original_size : Int,
) -> Bytes raise {
  // Use the modern bytes-based implementation directly
  let zlib_data : ZlibData = {
    compressed_bytes: compressed_data,
    original_size,
    adler32_checksum: 0L, // Will be read from data
  }
  zlib_decompress_bytes(zlib_data)
}
