// Deflate compression/decompression implementation
// This is a simplified implementation focusing on basic functionality

// Deflate compressed data structure

///|
pub struct DeflateData {
  compressed_bytes : Bytes
  original_size : Int
  adler32_checksum : @adler32.Adler32
}

// Compress data using deflate algorithm

///|
pub fn deflate_compress(data : Bytes, _level : Level) -> DeflateData raise {
  // Use @flate.Writer for actual compression
  let buf = @io.Buffer::new()
  let writer = @flate.Writer::new(buf)
  let closer : &@io.WriteCloser = writer
  let (_, err) = writer.write(@io.Slice::new(data.to_array()))
  match err {
    Some(e) => fail("Deflate compression failed: " + e.to_string())
    None => ()
  }
  match closer.close() {
    Some(e) => fail("Deflate compression failed: " + e.to_string())
    None => ()
  }
  let compressed_bytes = buf.to_bytes()
  let adler = @adler32.bytes(data)
  {
    compressed_bytes,
    original_size: data.length(),
    adler32_checksum: adler,
  }
}

// Decompress deflate data

///|
pub fn deflate_decompress(deflate_data : DeflateData) -> Bytes raise {
  // Decompress using flate.Reader
  if deflate_data.compressed_bytes.length() == 0 {
    return Bytes::from_array([])
  }
  let input = @io.Buffer::new()
  let (_, write_err) = input.write_bytes(deflate_data.compressed_bytes)
  match write_err {
    Some(e) => fail("Deflate input write failed: " + e.to_string())
    None => ()
  }
  let output = @io.Buffer::new()
  let reader = &@flate.Reader::new(input)
  let closer : &@io.Closer = reader
  let (_, copy_err) = @io.copy(output, reader)
  match copy_err {
    Some(e) => {
      let close_err = closer.close()
      match close_err {
        Some(close_e) =>
          fail(
            "Deflate decompression failed: " +
            e.to_string() +
            "; close error: " +
            close_e.to_string(),
          )
        None => fail("Deflate decompression failed: " + e.to_string())
      }
    }
    None => ()
  }
  let close_err = closer.close()
  match close_err {
    Some(e) => fail("Deflate close failed: " + e.to_string())
    None => ()
  }
  let decompressed_bytes = output.to_bytes()
  // Verify Adler-32 checksum of the decompressed data
  let computed_adler = @adler32.bytes(decompressed_bytes)
  if computed_adler == deflate_data.adler32_checksum {
    decompressed_bytes
  } else {
    fail("Adler-32 checksum mismatch")
  }
}

///|
/// Create deflate-compressed file data for ZIP
pub fn deflate_of_bytes(data : Bytes, _level : Level) -> Bytes raise {
  let buf = @io.Buffer::new()
  let writer = @flate.Writer::new(buf)
  let closer : &@io.WriteCloser = writer
  let (_, err) = writer.write(@io.Slice::new(data.to_array()))
  match err {
    Some(e) => fail("Deflate compression failed: " + e.to_string())
    None => ()
  }
  match closer.close() {
    Some(e) => fail("Deflate compression failed: " + e.to_string())
    None => ()
  }
  buf.to_bytes()
}

// Bytes-based API functions

///|
pub fn deflate_decompress_bytes(
  compressed_data : Bytes,
  _original_size : Int,
) -> Bytes raise {
  if compressed_data.length() == 0 {
    return Bytes::from_array([])
  }
  let input = @io.Buffer::new()
  let (_, write_err) = input.write_bytes(compressed_data)
  match write_err {
    Some(e) => fail("Deflate input write failed: " + e.to_string())
    None => ()
  }
  let output = @io.Buffer::new()
  let reader = &@flate.Reader::new(input)
  let closer : &@io.Closer = reader
  let (_, copy_err) = @io.copy(output, reader)
  match copy_err {
    Some(e) => {
      let close_err = closer.close()
      match close_err {
        Some(close_e) =>
          fail(
            "Deflate decompression failed: " +
            e.to_string() +
            "; close error: " +
            close_e.to_string(),
          )
        None => fail("Deflate decompression failed: " + e.to_string())
      }
    }
    None => ()
  }
  let close_err = closer.close()
  match close_err {
    Some(e) => fail("Deflate close failed: " + e.to_string())
    None => ()
  }
  output.to_bytes()
}

///|
pub fn deflate_decompress_raw_bytes(
  compressed_data : Bytes,
  _original_size : Int,
) -> Bytes raise {
  deflate_decompress_bytes(compressed_data, _original_size)
}
