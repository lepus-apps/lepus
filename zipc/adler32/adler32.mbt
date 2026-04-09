// Adler-32 checksum implementation for zlib format
// Adler-32 is defined as: a = 1 + sum of bytes, b = sum of a values, result = b * 65536 + a

///|
pub(all) struct Adler32(Int64) derive(Eq)

///|
let adler32_base : Int64 = 65521L // Largest prime smaller than 65536

// Create a new Adler-32 checksum (initial value)

///|
fn new_adler32() -> Adler32 {
  Adler32(1L)
}

// Update Adler-32 with a single byte

///|
fn adler32_update_byte(adler : Adler32, byte : Byte) -> Adler32 {
  let a = adler.0 & 0xffffL
  let b = adler.0 >> 16
  let new_a = (a + byte.to_int64()) % adler32_base
  let new_b = (b + new_a) % adler32_base
  Adler32((new_b << 16) | new_a)
}

// Update Adler-32 with bytes (more efficient for binary data)

///|
fn adler32_update_bytes(adler : Adler32, data : Bytes) -> Adler32 {
  let mut result = adler
  for d in data {
    result = adler32_update_byte(result, d)
  }
  result
}

// Compute Adler-32 of bytes (private - legacy support)

///|
pub fn bytes(data : Bytes) -> Adler32 {
  let adler = new_adler32()
  adler32_update_bytes(adler, data)
}

// Check if two Adler-32 values are equal (private - use == operator instead)

///|
pub impl Show for Adler32 with output(adler, logger) {
  let hex_chars = "0123456789abcdef"
  let mut result = ""
  let mut value = adler.0
  for i = 0; i < 8; i = i + 1 {
    let digit = value.land(0xfL).to_int()
    result = hex_chars[digit].to_string() + result
    value = value >> 4
  }
  logger.write_string("0x" + result)
}
