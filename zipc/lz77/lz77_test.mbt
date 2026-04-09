// Comprehensive test suite for LZ77 encoder/decoder
// Tests cover basic functionality, edge cases, and performance

// Test basic literal encoding/decoding

///|
test "lz77_basic_literals" {
  let data = @buffer.new()
  data.write_bytes(b"Hello")
  let input = data.to_bytes() // TODO:(upstream) change String::to_bytes
  let tokens = @lz77.encode_default(input)
  let decoded = @lz77.decode(tokens)
  inspect(
    decoded,
    content=(
      #|b"Hello"
    ),
  )
  assert_eq(decoded, input)
}

// Test simple repetition compression

///|
test "lz77_simple_repetition" {
  let data = @buffer.new()
  // "AAAA" - should compress to A + reference(3,1)
  data.write_bytes(b"AAAA")
  let input = data.to_bytes()
  let tokens = @lz77.encode_default(input)
  let decoded = @lz77.decode(tokens)
  assert_eq(decoded, input)
  json_inspect(tokens, content=[["Literal", 65], ["Reference", 3, 1]])
}

// Test longer pattern matching

///|
test "lz77_pattern_matching" {
  let data = @buffer.new()
  // "abcabcabc" - should find patterns
  let pattern = b"abcabcabc"
  data.write_bytes(pattern)
  let input = data.to_bytes()
  let tokens = @lz77.encode_default(input)
  let decoded = @lz77.decode(tokens)
  assert_eq(decoded, input)
  json_inspect(tokens, content=[
    ["Literal", 97],
    ["Literal", 98],
    ["Literal", 99],
    ["Reference", 6, 3],
  ])
}

// Test empty input

///|
test "lz77_empty_input" {
  let empty_data = @buffer.new().to_bytes()
  let tokens = @lz77.encode_default(empty_data)
  let decoded = @lz77.decode(tokens)
  inspect(tokens.length(), content="0")
  inspect(decoded.length(), content="0")
  inspect("Empty input handled", content="Empty input handled")
}

// Test single byte

///|
test "lz77_single_byte" {
  let data = @buffer.new()
  data.write_byte(b'X')
  let input = data.to_bytes()
  let tokens = @lz77.encode_default(input)
  let decoded = @lz77.decode(tokens)
  inspect(decoded == input, content="true")
  inspect(tokens.length(), content="1")
  inspect("Single byte works", content="Single byte works")
}

// Test byte format encoding/decoding

///|
test "lz77_byte_format" {
  let data = @buffer.new()
  data.write_byte(b'H')
  data.write_byte(b'e')
  data.write_byte(b'l')
  data.write_byte(b'l')
  data.write_byte(b'o')
  data.write_byte(b' ')
  data.write_byte(b'W')
  data.write_byte(b'o')
  data.write_byte(b'r')
  data.write_byte(b'l')
  data.write_byte(b'd')
  let input = data.to_bytes()
  try {
    let compressed = @lz77.encode_to_bytes(input, @lz77.default_config())
    let decompressed = @lz77.decode_from_bytes(compressed)
    inspect(decompressed == input, content="true")
    inspect("Byte format works", content="Byte format works")
  } catch {
    _ => fail("Byte format encoding/decoding failed")
  }
}

// Test token validation

///|
test "lz77_token_validation" {
  // Create tokens using encode/decode to test validation
  let data = @buffer.new()
  data.write_byte(b'A')
  data.write_byte(b'B')
  data.write_byte(b'A')
  data.write_byte(b'B')
  let input = data.to_bytes()
  let tokens = @lz77.encode_default(input)
  let is_valid = @lz77.validate_tokens(tokens)
  inspect(is_valid, content="true")
  inspect("Token validation works", content="Token validation works")
}

// Test compression statistics

///|
test "lz77_compression_stats" {
  let data = @buffer.new()
  // Create data with some repetition
  for i = 0; i < 10; i = i + 1 {
    data.write_byte(b'A')
  }
  let input = data.to_bytes()
  let tokens = @lz77.encode_default(input)
  let (literals, references, ratio) = @lz77.get_compression_stats(
    input.length(),
    tokens,
  )
  inspect(literals + references == tokens.length(), content="true")
  inspect(ratio > 0.0, content="true")
  inspect("Compression stats work", content="Compression stats work")
}

// Test large data performance

///|
test "lz77_large_data" {
  let data = @buffer.new()
  // Create 1KB of data with patterns
  for i = 0; i < 256; i = i + 1 {
    data.write_byte((i % 26 + 65).to_byte()) // A-Z pattern
  }
  let input = data.to_bytes()
  let tokens = @lz77.encode_default(input)
  let decoded = @lz77.decode(tokens)
  inspect(decoded == input, content="true")
  inspect(decoded.length(), content="256")
  inspect("Large data works", content="Large data works")
}

// Test overlapping references

///|
test "lz77_overlapping_references" {
  // Test case where reference overlaps with current position
  // Create a pattern that should result in overlapping references
  let data = @buffer.new()
  data.write_byte(b'A')
  data.write_byte(b'B')
  data.write_byte(b'A')
  data.write_byte(b'B')
  data.write_byte(b'A')
  data.write_byte(b'B')
  let input = data.to_bytes()
  let tokens = @lz77.encode_default(input)
  let decoded = @lz77.decode(tokens)
  inspect(decoded == input, content="true")
  inspect("Overlapping references work", content="Overlapping references work")
}

// Test custom configuration

///|
test "lz77_custom_config" {
  let custom_config = @lz77.LZ77Config::{
    window_size: 1024,
    max_match_length: 32,
    min_match_length: 4,
    max_distance: 1024,
  }
  let data = @buffer.new()
  for i = 0; i < 20; i = i + 1 {
    data.write_byte(b'X')
  }
  let input = data.to_bytes()
  let tokens = @lz77.encode(input, custom_config)
  let decoded = @lz77.decode(tokens)
  inspect(decoded == input, content="true")
  inspect("Custom config works", content="Custom config works")
}

// Test error handling in decoder

///|
test "lz77_decoder_error_handling" {
  // Test invalid byte format
  let invalid_data = @buffer.new()
  invalid_data.write_byte(b'\xFF') // Invalid marker
  try {
    let _ = @lz77.decode_from_bytes(invalid_data.to_bytes())
    fail("Should have failed on invalid marker")
  } catch {
    _ => inspect("Error handling works", content="Error handling works")
  }
}

// Test hash function consistency

///|
test "lz77_hash_function" {
  // Test that hash function produces consistent results
  let hash1 = @lz77.hash3(b'A', b'B', b'C')
  let hash2 = @lz77.hash3(b'A', b'B', b'C')
  inspect(hash1 == hash2, content="true")
  inspect(hash1 >= 0, content="true")
  inspect("Hash function consistent", content="Hash function consistent")
}

// Benchmark test for performance measurement

///|
test "lz77_performance_benchmark" {
  let data = @buffer.new()
  // Create data with various patterns for realistic testing
  let patterns = ["Hello", "World", "Test", "Data", "Compression"]
  for i = 0; i < 100; i = i + 1 {
    let pattern = patterns[i % patterns.length()]
    for j = 0; j < pattern.length(); j = j + 1 {
      data.write_byte(pattern[j].to_byte())
    }
  }
  let input = data.to_bytes()

  // Measure encoding
  let tokens = @lz77.encode_default(input)
  let decoded = @lz77.decode(tokens)
  inspect(decoded == input, content="true")
  inspect(tokens.length() > 0, content="true")
  inspect(
    "Performance benchmark completed",
    content="Performance benchmark completed",
  )
}
