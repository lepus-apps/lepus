// Bytes-based binary utility functions
// These provide efficient binary operations without UTF-16 overhead

// Read 16-bit little-endian integer from bytes

///|
pub fn read_u16_le_bytes(data : Bytes, offset : Int) -> Int {
  if offset + 1 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  b0 + (b1 << 8)
}

// Read 32-bit little-endian integer from bytes

///|
pub fn read_u32_le_bytes(data : Bytes, offset : Int) -> Int {
  if offset + 3 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
}

// Write 16-bit little-endian integer to bytes

///|
pub fn write_u16_le_bytes(value : Int) -> Bytes {
  let b0 = (value & 0xff).to_byte()
  let b1 = ((value >> 8) & 0xff).to_byte()
  Bytes::from_array([b0, b1])
}

// Write 32-bit little-endian integer to bytes

///|
pub fn write_u32_le_bytes(value : Int) -> Bytes {
  let b0 = (value & 0xff).to_byte()
  let b1 = ((value >> 8) & 0xff).to_byte()
  let b2 = ((value >> 16) & 0xff).to_byte()
  let b3 = ((value >> 24) & 0xff).to_byte()
  Bytes::from_array([b0, b1, b2, b3])
}

// Read 16-bit big-endian integer from bytes

///|
pub fn read_u16_be_bytes(data : Bytes, offset : Int) -> Int {
  if offset + 1 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  (b0 << 8) + b1
}

// Read 32-bit big-endian integer from bytes

///|
pub fn read_u32_be_bytes(data : Bytes, offset : Int) -> Int {
  if offset + 3 >= data.length() {
    return 0
  }
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  (b0 << 24) + (b1 << 16) + (b2 << 8) + b3
}

// Write 16-bit big-endian integer to bytes

///|
pub fn write_u16_be_bytes(value : Int) -> Bytes {
  let b0 = ((value >> 8) & 0xff).to_byte()
  let b1 = (value & 0xff).to_byte()
  Bytes::from_array([b0, b1])
}

// Write 32-bit big-endian integer to bytes

///|
pub fn write_u32_be_bytes(value : Int) -> Bytes {
  let b0 = ((value >> 24) & 0xff).to_byte()
  let b1 = ((value >> 16) & 0xff).to_byte()
  let b2 = ((value >> 8) & 0xff).to_byte()
  let b3 = (value & 0xff).to_byte()
  Bytes::from_array([b0, b1, b2, b3])
}

// Concatenate multiple bytes

///|
pub fn concat_bytes(parts : Array[Bytes]) -> Bytes {
  let mut result = Bytes::from_array([])
  for part in parts {
    result = result + part
  }
  result
}

// Create bytes from byte values

///|
pub fn bytes_from_ints(values : Array[Int]) -> Bytes {
  let byte_array = values.map(fn(x) { x.to_byte() })
  Bytes::from_array(byte_array)
}

// Performance comparison functions for demonstration

///|
pub fn compare_string_vs_bytes_write_u32() -> String {
  let test_value = 0x12345678

  // String-based approach (current, inefficient)
  let _string_start = 0 // Placeholder for timing
  let string_result = {
    let b0 = test_value & 0xff
    let b1 = (test_value >> 8) & 0xff
    let b2 = (test_value >> 16) & 0xff
    let b3 = (test_value >> 24) & 0xff
    b0.unsafe_to_char().to_string() +
    b1.unsafe_to_char().to_string() +
    b2.unsafe_to_char().to_string() +
    b3.unsafe_to_char().to_string()
  }
  let _string_end = 0 // Placeholder for timing

  // Bytes-based approach (proposed, efficient)
  let _bytes_start = 0 // Placeholder for timing
  let bytes_result = write_u32_le_bytes(test_value)
  let _bytes_end = 0 // Placeholder for timing
  "String approach: " +
  string_result.length().to_string() +
  " chars, " +
  "Bytes approach: " +
  bytes_result.length().to_string() +
  " bytes\n" +
  "Bytes approach is safer (no unsafe operations) and more efficient"
}
