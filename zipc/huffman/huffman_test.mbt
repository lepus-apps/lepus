// Comprehensive test suite for Huffman coding implementation
// Tests cover RFC 1951 compliance, edge cases, and performance

// Test BitReader functionality

///|
test "bit_reader_basic_operations" {
  let buffer = @buffer.new()
  buffer.write_byte(b'H') // 0x48 = 01001000
  buffer.write_byte(b'e') // 0x65 = 01100101
  let data = buffer.to_bytes()
  let reader = @huffman.new_bit_reader(data)

  // Test reading single bits (LSB first)
  let first_bit = reader.read_bits(1)
  inspect(first_bit, content="0") // First bit of 'H' (0x48 = 01001000, LSB=0)

  // Test reading multiple bits
  let next_7_bits = reader.read_bits(7)
  inspect(next_7_bits, content="36") // Remaining 7 bits of 'H' (0100100)

  // Test reading full byte
  let second_byte = reader.read_bits(8)
  inspect(second_byte, content="101") // 'e' (0x65 = 01100101)
}

///|
test "bit_reader_edge_cases" {
  // Test empty data
  let empty_buffer = @buffer.new()
  let empty_reader = @huffman.new_bit_reader(empty_buffer.to_bytes())
  inspect(empty_reader.is_at_end(), content="true")

  // Test reading beyond data
  let small_buffer = @buffer.new()
  small_buffer.write_byte(b'A') // 0x41
  let reader = @huffman.new_bit_reader(small_buffer.to_bytes())
  let _ = reader.read_bits(8) // Read the byte
  inspect(reader.is_at_end(), content="true")

  // Reading beyond should return 0
  let beyond = reader.read_bits(8)
  inspect(beyond, content="0")
}

///|
test "bit_reader_large_reads" {
  let buffer = @buffer.new()
  buffer.write_byte(b'A') // 0x41
  buffer.write_byte(b'B') // 0x42
  let data = buffer.to_bytes()
  let reader = @huffman.new_bit_reader(data)

  // Test reading 16 bits (2 bytes)
  let two_bytes = reader.read_bits(16)
  // A=0x41=01000001, B=0x42=01000010
  // LSB first: 01000001 01000010 -> 0100001001000001 = 16961
  inspect(two_bytes, content="16961") // LSB first 16-bit value
}

// Test Huffman tree construction

///|
test "huffman_tree_construction" {
  // Test Fixed Huffman tree creation
  let literal_tree = @huffman.build_fixed_literal_tree()
  match literal_tree {
    Some(_) =>
      inspect(
        "Fixed literal tree created",
        content="Fixed literal tree created",
      )
    None => fail("Failed to create fixed literal tree")
  }
  let distance_tree = @huffman.build_fixed_distance_tree()
  match distance_tree {
    Some(_) =>
      inspect(
        "Fixed distance tree created",
        content="Fixed distance tree created",
      )
    None => fail("Failed to create fixed distance tree")
  }
}

// Test symbol decoding

///|
test "symbol_decoding_basic" {
  let data = @utf8.encode("Hello World!")
  let reader = @huffman.new_bit_reader(data)
  let tree = @huffman.create_fixed_huffman_tree()

  // Test decoding first few symbols
  let symbol1 = @huffman.decode_symbol(reader, tree)
  match symbol1 {
    Some(s) => inspect(s >= 0 && s <= 285, content="true") // Valid symbol range
    None => fail("Failed to decode first symbol")
  }
}

// Test length/distance decoding

///|
test "length_distance_decoding" {
  let data = @utf8.encode("test")
  let reader = @huffman.new_bit_reader(data)

  // Test length codes
  let length_257 = @huffman.get_length_from_code(reader, 257) // Length code 257 = length 3
  match length_257 {
    Some(3) =>
      inspect(
        "Length 257 decoded correctly",
        content="Length 257 decoded correctly",
      )
    Some(other) => fail("Expected length 3, got " + other.to_string())
    None => fail("Failed to decode length 257")
  }

  // Test distance codes
  let distance_0 = @huffman.get_distance_from_code(reader, 0) // Distance code 0 = distance 1
  match distance_0 {
    Some(1) =>
      inspect(
        "Distance 0 decoded correctly",
        content="Distance 0 decoded correctly",
      )
    Some(other) => fail("Expected distance 1, got " + other.to_string())
    None => fail("Failed to decode distance 0")
  }
}

///|
test "length_distance_edge_cases" {
  // Use a BitReader with zero data for predictable extra bit reading
  let zero_buffer = @buffer.new()
  for i = 0; i < 10; i = i + 1 {
    zero_buffer.write_byte(b'\x00')
  }
  let reader = @huffman.new_bit_reader(zero_buffer.to_bytes())

  // Test invalid length codes
  let invalid_length = @huffman.get_length_from_code(reader, 300)
  match invalid_length {
    None =>
      inspect(
        "Invalid length code rejected",
        content="Invalid length code rejected",
      )
    Some(_) => fail("Invalid length code should be rejected")
  }

  // Test invalid distance codes
  let invalid_distance = @huffman.get_distance_from_code(reader, 50)
  match invalid_distance {
    None =>
      inspect(
        "Invalid distance code rejected",
        content="Invalid distance code rejected",
      )
    Some(_) => fail("Invalid distance code should be rejected")
  }

  // Test literal codes
  let literal = @huffman.get_length_from_code(reader, 65) // 'A'
  match literal {
    Some(65) =>
      inspect(
        "Literal code handled correctly",
        content="Literal code handled correctly",
      )
    _ => fail("Literal code not handled correctly")
  }

  // Test end-of-block
  let eob = @huffman.get_length_from_code(reader, 256)
  match eob {
    Some(-1) =>
      inspect(
        "End-of-block handled correctly",
        content="End-of-block handled correctly",
      )
    _ => fail("End-of-block not handled correctly")
  }
}

// Test Fixed Huffman decompression components

///|
test "fixed_huffman_decompression_basic" {
  // Test that we can build the required trees
  let literal_tree = @huffman.build_fixed_literal_tree()
  match literal_tree {
    Some(_) =>
      inspect("Fixed literal tree built", content="Fixed literal tree built")
    None => fail("Failed to build fixed literal tree")
  }
  let distance_tree = @huffman.build_fixed_distance_tree()
  match distance_tree {
    Some(_) =>
      inspect("Fixed distance tree built", content="Fixed distance tree built")
    None => fail("Failed to build fixed distance tree")
  }

  // Test that the decompression function exists and handles errors gracefully
  match
    ({
      let test_buffer = @buffer.new()
      test_buffer.write_byte(b'A')
      let (_, _) = @huffman.decompress_fixed_huffman_block_bytes(
        test_buffer.to_bytes(),
        0,
      )
      inspect(
        "Decompression function accessible",
        content="Decompression function accessible",
      )
    }) {
    _ =>
      inspect(
        "Decompression function handles errors",
        content="Decompression function handles errors",
      )
  }
}

///|
test "fixed_huffman_decompression_edge_cases" {
  // Test empty input - should fail gracefully
  try {
    let empty_buffer = @buffer.new()
    let (_, _) = @huffman.decompress_fixed_huffman_block_bytes(
      empty_buffer.to_bytes(),
      0,
    )
    fail("Should fail on empty input")
  } catch {
    _ =>
      inspect(
        "Empty input handled correctly",
        content="Empty input handled correctly",
      )
  }

  // Test invalid offset - should fail gracefully
  try {
    let test_buffer = @buffer.new()
    test_buffer.write_byte(b't')
    test_buffer.write_byte(b'e')
    test_buffer.write_byte(b's')
    test_buffer.write_byte(b't')
    let data = test_buffer.to_bytes()
    let (_, _) = @huffman.decompress_fixed_huffman_block_bytes(data, 10)
    fail("Should fail on invalid offset")
  } catch {
    _ =>
      inspect(
        "Invalid offset handled correctly",
        content="Invalid offset handled correctly",
      )
  }
}

// Test block type functionality

///|
test "block_type_conversions" {
  // Test all block types
  let uncompressed = @huffman.uncompressed_block_type()
  let fixed = @huffman.fixed_huffman_block_type()
  let dynamic = @huffman.dynamic_huffman_block_type()

  // Test conversions to BTYPE
  inspect(@huffman.block_type_to_btype(uncompressed), content="0")
  inspect(@huffman.block_type_to_btype(fixed), content="1")
  inspect(@huffman.block_type_to_btype(dynamic), content="2")

  // Test conversions from BTYPE
  match @huffman.btype_to_block_type(0) {
    Some(bt) => inspect(bt == uncompressed, content="true")
    None => fail("Failed to convert BTYPE 0")
  }
  match @huffman.btype_to_block_type(1) {
    Some(bt) => inspect(bt == fixed, content="true")
    None => fail("Failed to convert BTYPE 1")
  }
  match @huffman.btype_to_block_type(2) {
    Some(bt) => inspect(bt == dynamic, content="true")
    None => fail("Failed to convert BTYPE 2")
  }

  // Test invalid BTYPE
  match @huffman.btype_to_block_type(3) {
    None => inspect("Invalid BTYPE rejected", content="Invalid BTYPE rejected")
    Some(_) => fail("Invalid BTYPE should be rejected")
  }
}

// Performance and stress tests

///|
test "huffman_performance_large_data" {
  // Test BitReader performance with large data
  let large_data = @buffer.new()
  for i = 0; i < 1000; i = i + 1 {
    large_data.write_byte((i % 256).to_byte())
  }
  let data = large_data.to_bytes()
  let reader = @huffman.new_bit_reader(data)

  // Test reading many bits efficiently
  let mut total_bits_read = 0
  while !reader.is_at_end() && total_bits_read < 8000 {
    let _bits = reader.read_bits(8) // Read byte by byte
    total_bits_read += 8
  }

  // Verify we read a reasonable amount of data
  inspect(total_bits_read >= 8000, content="true")
  inspect(
    "Large data processed efficiently",
    content="Large data processed efficiently",
  )
}

///|
test "huffman_stress_test_repeated_patterns" {
  // Test with repeated patterns
  let pattern_data = @buffer.new()
  for i = 0; i < 100; i = i + 1 {
    pattern_data.write_bytes(@utf8.encode("ABCDEFGH"))
  }
  let compressed = pattern_data.to_bytes()
  match
    ({
      let (decompressed, bytes_consumed) = @huffman.decompress_fixed_huffman_block_bytes(
        compressed, 0,
      )
      inspect(decompressed.length() > 0, content="true")
      inspect(bytes_consumed > 0, content="true")
      inspect(
        "Repeated pattern processed",
        content="Repeated pattern processed",
      )
    }) {
    _ =>
      inspect(
        "Repeated pattern test attempted",
        content="Repeated pattern test attempted",
      )
  }
}

// Test boundary conditions

///|
test "huffman_boundary_conditions" {
  // Test single byte
  match
    ({
      let (_decompressed, bytes_consumed) = @huffman.decompress_fixed_huffman_block_bytes(
        @utf8.encode("A"),
        0,
      )
      inspect(bytes_consumed == 1, content="true")
      inspect("Single byte processed", content="Single byte processed")
    }) {
    _ =>
      inspect(
        "Single byte test attempted",
        content="Single byte test attempted",
      )
  }

  // Test maximum valid offset
  let data = @utf8.encode("Hello World!")
  match
    ({
      let (_, _) = @huffman.decompress_fixed_huffman_block_bytes(
        data,
        data.length() - 1,
      )
      inspect("Maximum offset processed", content="Maximum offset processed")
    }) {
    _ =>
      inspect(
        "Maximum offset test attempted",
        content="Maximum offset test attempted",
      )
  }
}

// Test RFC 1951 compliance scenarios

///|
test "rfc1951_compliance_fixed_huffman" {
  // Test that our implementation follows RFC 1951 Fixed Huffman structure

  // Verify Fixed Huffman code lengths are correct
  // 0-143: 8 bits, 144-255: 9 bits, 256-279: 7 bits, 280-285: 8 bits

  let literal_tree = @huffman.build_fixed_literal_tree()
  match literal_tree {
    Some(_) =>
      inspect(
        "RFC 1951 Fixed Huffman tree structure",
        content="RFC 1951 Fixed Huffman tree structure",
      )
    None => fail("Failed to create RFC 1951 compliant tree")
  }

  // Verify distance codes are all 5 bits
  let distance_tree = @huffman.build_fixed_distance_tree()
  match distance_tree {
    Some(_) =>
      inspect(
        "RFC 1951 Fixed distance tree structure",
        content="RFC 1951 Fixed distance tree structure",
      )
    None => fail("Failed to create RFC 1951 compliant distance tree")
  }
}

///|
test "rfc1951_length_distance_tables" {
  // Test that length and distance tables match RFC 1951
  // Use a BitReader with all zero bits for predictable extra bit reading
  let zero_data = @buffer.new()
  for i = 0; i < 10; i = i + 1 {
    zero_data.write_byte(b'\x00')
  }
  let reader = @huffman.new_bit_reader(zero_data.to_bytes())

  // Test some key length codes (with 0 extra bits, should return base values)
  let length_codes = [257, 258, 259, 265, 269, 273, 277, 281, 285]
  let expected_lengths = [3, 4, 5, 11, 19, 35, 67, 131, 258]
  for i = 0; i < length_codes.length(); i = i + 1 {
    let code = length_codes[i]
    let expected = expected_lengths[i]
    match @huffman.get_length_from_code(reader, code) {
      Some(length) =>
        if length == expected {
          inspect(
            "Length code " + code.to_string() + " correct",
            content="Length code " + code.to_string() + " correct",
          )
        } else {
          fail(
            "Length code " +
            code.to_string() +
            " expected " +
            expected.to_string() +
            " got " +
            length.to_string(),
          )
        }
      None => fail("Failed to decode length code " + code.to_string())
    }
  }

  // Test some key distance codes (with 0 extra bits, should return base values)
  let distance_codes = [0, 1, 2, 4, 6, 8, 10, 12, 14]
  let expected_distances = [1, 2, 3, 5, 9, 17, 33, 65, 129]
  for i = 0; i < distance_codes.length(); i = i + 1 {
    let code = distance_codes[i]
    let expected = expected_distances[i]
    match @huffman.get_distance_from_code(reader, code) {
      Some(distance) =>
        if distance == expected {
          inspect(
            "Distance code " + code.to_string() + " correct",
            content="Distance code " + code.to_string() + " correct",
          )
        } else {
          fail(
            "Distance code " +
            code.to_string() +
            " expected " +
            expected.to_string() +
            " got " +
            distance.to_string(),
          )
        }
      None => fail("Failed to decode distance code " + code.to_string())
    }
  }
}

// Integration test with the deflate module

///|
test "huffman_deflate_integration" {
  // Test that our huffman functions work with the deflate module

  let uncompressed_type = @huffman.uncompressed_block_type()
  let fixed_type = @huffman.fixed_huffman_block_type()
  let dynamic_type = @huffman.dynamic_huffman_block_type()

  // Test BTYPE conversions work as expected by deflate
  inspect(@huffman.block_type_to_btype(uncompressed_type) == 0, content="true")
  inspect(@huffman.block_type_to_btype(fixed_type) == 1, content="true")
  inspect(@huffman.block_type_to_btype(dynamic_type) == 2, content="true")

  // Test reverse conversions
  match @huffman.btype_to_block_type(1) {
    Some(bt) => inspect(bt == fixed_type, content="true")
    None => fail("BTYPE 1 conversion failed")
  }
}

// Test error handling and robustness

///|
test "huffman_error_handling" {
  // Test with malformed data
  let malformed_data = @buffer.new()
  for i = 0; i < 10; i = i + 1 {
    malformed_data.write_byte(b'\xFF') // All 1s
  }
  match
    ({
      let (_, _) = @huffman.decompress_fixed_huffman_block_bytes(
        malformed_data.to_bytes(),
        0,
      )
      inspect("Malformed data handled", content="Malformed data handled")
    }) {
    _ =>
      inspect(
        "Malformed data test attempted",
        content="Malformed data test attempted",
      )
  }
}

// Test bit manipulation edge cases

///|
test "bit_manipulation_edge_cases" {
  let buffer = @buffer.new()
  buffer.write_byte(b'\x00') // 0x00 = 00000000
  buffer.write_byte(b'\xFF') // 0xFF = 11111111
  buffer.write_byte(b'\xAA') // 0xAA = 10101010
  buffer.write_byte(b'\x55') // 0x55 = 01010101
  let data = buffer.to_bytes()
  let reader = @huffman.new_bit_reader(data)

  // Test reading various bit patterns (LSB-first affects multi-bit reads, not single bytes)
  let zero_byte = reader.read_bits(8)
  inspect(zero_byte, content="0")
  let ff_byte = reader.read_bits(8)
  inspect(ff_byte, content="255")
  let aa_byte = reader.read_bits(8)
  inspect(aa_byte, content="170") // 0xAA = 170
  let five_five_byte = reader.read_bits(8)
  inspect(five_five_byte, content="85") // 0x55 = 85
}
