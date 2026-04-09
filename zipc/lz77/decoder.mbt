// LZ77 Decoder Implementation
// Decodes LZ77 compressed data back to original bytes

// Decode LZ77 tokens back to original bytes

///|
pub fn decode(tokens : Array[LZ77Token]) -> Bytes raise {
  let state = new_decoder_state()
  for token in tokens {
    match token {
      LZ77Token::Literal(byte) => {
        // Add literal byte to output
        state.output_buffer.write_byte(byte)
        state.position += 1
      }
      LZ77Token::Reference(length, distance) =>
        // Copy bytes from previous position
        copy_reference(state, length, distance)
    }
  }
  state.output_buffer.to_bytes()
}

// Copy bytes from a back-reference

///|
fn copy_reference(
  state : DecoderState,
  length : Int,
  distance : Int,
) -> Unit raise {
  let initial_output_bytes = state.output_buffer.to_bytes()
  let start_pos = initial_output_bytes.length() - distance

  // Validate the reference
  if start_pos < 0 {
    fail("Invalid LZ77 reference: distance too large")
  }

  // Copy bytes one by one (handles overlapping copies correctly)
  // For overlapping copies, we need to read from the buffer dynamically
  for i = 0; i < length; i = i + 1 {
    let copy_pos = start_pos + i

    // Get current state of output buffer for each byte
    let current_output_bytes = state.output_buffer.to_bytes()
    if copy_pos >= 0 && copy_pos < current_output_bytes.length() {
      let byte_to_copy = current_output_bytes[copy_pos]
      state.output_buffer.write_byte(byte_to_copy)
    } else {
      fail("Invalid LZ77 reference: copy position out of bounds")
    }
    state.position += 1
  }
}

// Decode from byte format (matches encode_to_bytes format)

///|
pub fn decode_from_bytes(data : Bytes) -> Bytes raise {
  let state = new_decoder_state()
  let mut pos = 0
  while pos < data.length() {
    if pos >= data.length() {
      break
    }
    let marker = data[pos]
    pos += 1
    if marker.to_int() == 0 {
      // Literal byte
      if pos >= data.length() {
        fail("Incomplete literal in LZ77 data")
      }
      let byte = data[pos]
      pos += 1
      state.output_buffer.write_byte(byte)
      state.position += 1
    } else if marker.to_int() == 1 {
      // Reference
      let (length, new_pos1) = read_varint(data, pos)
      let (distance, new_pos2) = read_varint(data, new_pos1)
      pos = new_pos2
      copy_reference(state, length, distance)
    } else {
      fail("Invalid marker in LZ77 data: " + marker.to_int().to_string())
    }
  }
  state.output_buffer.to_bytes()
}

// Read variable-length integer

///|
fn read_varint(data : Bytes, start_pos : Int) -> (Int, Int) {
  let mut pos = start_pos
  let mut value = 0
  let mut shift = 0
  while pos < data.length() {
    let byte = data[pos].to_int()
    pos += 1
    value = value + ((byte % 128) << shift)
    shift += 7
    if byte < 128 {
      break
    }
  }
  (value, pos)
}

// Validate LZ77 tokens for correctness

///|
pub fn validate_tokens(tokens : Array[LZ77Token]) -> Bool {
  let mut output_length = 0
  for token in tokens {
    match token {
      LZ77Token::Literal(_) => output_length += 1
      LZ77Token::Reference(length, distance) => {
        // Check if reference is valid
        if distance <= 0 || distance > output_length {
          return false
        }
        if length <= 0 {
          return false
        }
        output_length += length
      }
    }
  }
  true
}

// Get compression statistics

///|
pub fn get_compression_stats(
  original_size : Int,
  tokens : Array[LZ77Token],
) -> (Int, Int, Double) {
  let mut literal_count = 0
  let mut reference_count = 0
  let mut compressed_size = 0
  for token in tokens {
    match token {
      LZ77Token::Literal(_) => {
        literal_count += 1
        compressed_size += 2 // marker + byte
      }
      LZ77Token::Reference(length, distance) => {
        reference_count += 1
        // Estimate compressed size (marker + varint encoding)
        compressed_size += 1 + varint_size(length) + varint_size(distance)
      }
    }
  }
  let compression_ratio = if original_size > 0 {
    compressed_size.to_double() / original_size.to_double()
  } else {
    1.0
  }
  (literal_count, reference_count, compression_ratio)
}

// Estimate varint encoding size

///|
fn varint_size(value : Int) -> Int {
  if value < 128 {
    1
  } else if value < 16384 {
    2
  } else if value < 2097152 {
    3
  } else {
    4
  }
}
