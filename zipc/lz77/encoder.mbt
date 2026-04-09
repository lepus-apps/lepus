// LZ77 Encoder Implementation
// Implements sliding window compression with hash-based string matching
//
// This module provides the core LZ77 encoding functionality using a sliding window
// approach with hash chains for efficient string matching. The implementation follows
// the LZ77 algorithm as described in:
// - Ziv, J.; Lempel, A. (1977). "A universal algorithm for sequential data compression"
// - RFC 1951 (DEFLATE specification) for parameter compatibility
//
// Algorithm Overview:
// 1. Maintain a sliding window of recently processed data
// 2. Use hash tables to quickly find potential matches
// 3. For each position, find the longest match within the window
// 4. Output either a literal byte or a (length, distance) reference
//
// Performance Characteristics:
// - Time Complexity: O(n) average case, O(n²) worst case
// - Space Complexity: O(window_size) for hash tables
// - Compression Ratio: Depends on data redundancy, typically 30-70% for text

///|
/// Encode bytes using LZ77 compression algorithm
///
/// This is the main encoding function that processes input data and produces
/// a sequence of LZ77 tokens (literals and back-references).
///
/// # Parameters
/// - `data`: Input bytes to compress
/// - `config`: LZ77 configuration parameters (window size, match lengths, etc.)
///
/// # Returns
/// Array of LZ77Token representing the compressed data
///
/// # Algorithm Steps
/// 1. Initialize encoder state with hash tables
/// 2. For each position in input data:
///    a. Find the best match using hash-based search
///    b. Output literal or reference token
///    c. Update hash tables with new position
/// 3. Return the complete token sequence
///
/// # Example
/// ```
/// let data = b"Hello World Hello World"
/// let config = @lz77.default_config()
/// let tokens = @lz77.encode(data, config)
/// json_inspect(tokens, content=[
///   ["Literal", 72],
///   ["Literal", 101],
///   ["Literal", 108],
///   ["Literal", 108],
///   ["Literal", 111],
///   ["Literal", 32],
///   ["Literal", 87],
///   ["Literal", 111],
///   ["Literal", 114],
///   ["Literal", 108],
///   ["Literal", 100],
///   ["Literal", 32],
///   ["Reference", 11, 12],
/// ])
/// ```
pub fn encode(data : Bytes, config : LZ77Config) -> Array[LZ77Token] {
  // Handle empty input - no compression needed
  if data.length() == 0 {
    return []
  }

  // Initialize encoder state with hash tables and sliding window
  let state = new_encoder_state(config)
  let result = []

  // Main encoding loop - process each position in the input
  while state.position < data.length() {
    // Find the best match (literal or reference) at current position
    let token = find_best_match(data, state, config)
    result.push(token)

    // Update hash tables with current position for future matches
    // This makes the current position available for future lookups
    update_hash_tables(data, state, config)

    // Advance position based on token type
    match token {
      LZ77Token::Literal(_) =>
        // Literal: advance by 1 byte
        state.position += 1
      LZ77Token::Reference(length, _) => {
        // Reference: advance by match length, but also update hash tables
        // for all intermediate positions to maintain proper hash chains
        for i = 1; i < length; i = i + 1 {
          state.position += 1
          update_hash_tables(data, state, config)
        }
        state.position += 1
      }
    }
  }
  result
}

///|
/// Find the best match for the current position
///
/// This function implements the core string matching algorithm using hash chains.
/// It searches for the longest match within the sliding window and decides whether
/// to output a literal byte or a back-reference.
///
/// # Algorithm
/// 1. Check if we have enough bytes for a minimum match (3 bytes)
/// 2. Calculate hash for current 3-byte sequence
/// 3. Follow hash chain to find all positions with same hash
/// 4. For each candidate position:
///    a. Verify it's within distance limits
///    b. Calculate actual match length
///    c. Keep track of longest match found
/// 5. Return reference if match is long enough, otherwise literal
///
/// # Parameters
/// - `data`: Input data being compressed
/// - `state`: Current encoder state (position, hash tables)
/// - `config`: Configuration parameters (window size, match limits)
///
/// # Returns
/// LZ77Token::Literal(byte) or LZ77Token::Reference(length, distance)
///
/// # Performance Notes
/// - Hash lookup is O(1) average case
/// - Chain traversal is limited to prevent O(n²) worst case
/// - Early termination when maximum match length is found
fn find_best_match(
  data : Bytes,
  state : EncoderState,
  config : LZ77Config,
) -> LZ77Token {
  let pos = state.position

  // Need at least min_match_length bytes for a valid match
  // If we're too close to end of data, output literal
  if pos + config.min_match_length - 1 >= data.length() {
    return LZ77Token::Literal(data[pos])
  }

  // Calculate 3-byte rolling hash for current position
  // This hash is used to quickly find potential match candidates
  let hash = hash3(data[pos], data[pos + 1], data[pos + 2])
  let chain_head = state.hash_head[hash]

  // If no previous occurrence of this hash exists, output literal
  if chain_head == -1 {
    return LZ77Token::Literal(data[pos])
  }

  // Search for the longest match by following the hash chain
  let mut best_length = 0
  let mut best_distance = 0
  let mut current = chain_head
  let mut chain_count = 0
  let max_chain_length = 128 // Limit chain traversal to prevent O(n²) behavior

  // Follow hash chain to examine all positions with matching hash
  while current != -1 && chain_count < max_chain_length {
    let distance = pos - current

    // Validate distance constraints
    if distance > config.max_distance || distance <= 0 {
      break // Distance too large or invalid
    }

    // Check if position is still within the sliding window
    if current < state.window_start {
      break // Position has fallen out of the sliding window
    }

    // Calculate actual match length between current and candidate positions
    let match_length = find_match_length(
      data,
      pos,
      current,
      config.max_match_length,
    )

    // Update best match if this one is longer and meets minimum requirements
    if match_length >= config.min_match_length && match_length > best_length {
      best_length = match_length
      best_distance = distance

      // Early termination: if we found the maximum possible match, stop searching
      if best_length == config.max_match_length {
        break
      }
    }

    // Follow chain to next position with same hash
    current = state.hash_prev[current % config.window_size]
    chain_count += 1
  }
  if best_length >= config.min_match_length {
    LZ77Token::Reference(best_length, best_distance)
  } else {
    LZ77Token::Literal(data[pos])
  }
}

///|
/// Find the length of a match between two positions
///
/// This function compares bytes at two positions to determine how many
/// consecutive bytes match. It's used to calculate the actual match length
/// for potential back-references.
///
/// # Parameters
/// - `data`: Input data being processed
/// - `pos1`: Current position (where we're encoding)
/// - `pos2`: Candidate match position (from hash chain)
/// - `max_length`: Maximum allowed match length (from config)
///
/// # Returns
/// Number of consecutive matching bytes (0 to max_length)
///
/// # Algorithm
/// Compare bytes sequentially until:
/// - Maximum length is reached
/// - End of data is reached
/// - Bytes no longer match
///
/// # Performance
/// - Time complexity: O(match_length)
/// - Typically terminates quickly for non-matches
fn find_match_length(
  data : Bytes,
  pos1 : Int,
  pos2 : Int,
  max_length : Int,
) -> Int {
  let mut length = 0
  let data_length = data.length()

  // Compare bytes sequentially until mismatch or limits reached
  while length < max_length &&
        pos1 + length < data_length &&
        pos2 + length < data_length &&
        data[pos1 + length] == data[pos2 + length] {
    length += 1
  }
  length
}

///|
/// Update hash tables with new position
///
/// This function maintains the hash tables and sliding window as the encoder
/// advances through the input data. It's crucial for keeping the hash chains
/// current and ensuring efficient string matching.
///
/// # Parameters
/// - `data`: Input data being processed
/// - `state`: Encoder state containing hash tables and position
/// - `config`: Configuration with window size
///
/// # Operations
/// 1. Update sliding window boundaries
/// 2. Add current position to appropriate hash chain
/// 3. Maintain hash chain links for future lookups
///
/// # Hash Chain Structure
/// - `hash_head[hash]`: Most recent position with this hash
/// - `hash_prev[pos]`: Previous position in chain for position `pos`
/// - Chains are traversed backwards in time (newest to oldest)
///
/// # Sliding Window Management
/// - Window slides forward as encoding progresses
/// - Old positions outside window are effectively ignored
/// - Window size determines maximum back-reference distance
fn update_hash_tables(
  data : Bytes,
  state : EncoderState,
  config : LZ77Config,
) -> Unit {
  let pos = state.position

  // Update sliding window boundaries
  // Window start moves forward once we exceed window size
  if pos >= config.window_size {
    state.window_start = pos - config.window_size + 1
  }

  // Add current position to hash table if we have enough bytes for a hash
  // Need at least 3 bytes to calculate hash3
  if pos + 2 < data.length() {
    let hash = hash3(data[pos], data[pos + 1], data[pos + 2])
    let window_pos = pos % config.window_size // Circular buffer index

    // Update hash chain: link current position to previous head
    // This maintains a linked list of positions with the same hash
    state.hash_prev[window_pos] = state.hash_head[hash]
    state.hash_head[hash] = pos // Current position becomes new head
  }
}

///|
/// Encode with default DEFLATE-compatible configuration
///
/// This is a convenience function that uses the default LZ77 configuration
/// which is compatible with the DEFLATE compression standard (RFC 1951).
///
/// # Parameters
/// - `data`: Input bytes to compress
///
/// # Returns
/// Array of LZ77Token representing the compressed data
///
/// # Default Configuration
/// - Window size: 32768 bytes (32KB)
/// - Maximum match length: 258 bytes
/// - Minimum match length: 3 bytes
/// - Maximum distance: 32768 bytes
///
/// # Example
/// ```
/// let data = b"HelloxxHelloHelloello"
/// let tokens = @lz77.encode_default(data)
/// json_inspect(tokens, content=[
///   ["Literal", 72],
///   ["Literal", 101],
///   ["Literal", 108],
///   ["Literal", 108],
///   ["Literal", 111],
///   ["Literal", 120],
///   ["Literal", 120],
///   ["Reference", 5, 7],
///   ["Reference", 5, 5],
///   ["Reference", 4, 4],
/// ])
/// ```
pub fn encode_default(data : Bytes) -> Array[LZ77Token] {
  encode(data, default_config())
}

///|
/// Encode to byte format suitable for storage or transmission
///
/// This function encodes the input data and serializes the resulting tokens
/// into a byte format that can be stored or transmitted. The format uses
/// simple markers to distinguish between literals and references.
///
/// # Parameters
/// - `data`: Input bytes to compress
/// - `config`: LZ77 configuration parameters
///
/// # Returns
/// Serialized bytes representing the compressed data
///
/// # Byte Format
/// - Literal: `0x00` + byte_value
/// - Reference: `0x01` + varint(length) + varint(distance)
///
/// # Variable Integer Encoding
/// - Values < 128: single byte
/// - Values >= 128: multiple bytes with continuation bit
/// - LSB format with 7 data bits + 1 continuation bit per byte
///
/// # Example
/// ```
/// let data = b"Hello World Hello World"
/// let compressed = @lz77.encode_to_bytes(data, @lz77.default_config())
/// json_inspect(compressed.to_array(), content=[
///   0, 72, 0, 101, 0, 108, 0, 108, 0, 111, 0, 32, 0, 87, 0, 111, 0, 114, 0, 108,
///   0, 100, 0, 32, 1, 11, 12
/// ])
/// ```
pub fn encode_to_bytes(data : Bytes, config : LZ77Config) -> Bytes { // First, encode to token format
  let tokens = encode(data, config)
  let output = @buffer.new()
  // Serialize each token to byte format
  for token in tokens {
    match token {
      LZ77Token::Literal(byte) => {
        // Literal format: marker (0x00) + literal byte
        output.write_byte(b'\x00')
        output.write_byte(byte)
      }
      LZ77Token::Reference(length, distance) => {
        // Reference format: marker (0x01) + varint(length) + varint(distance)
        output.write_byte(b'\x01')
        write_uleb128(output, length)
        write_uleb128(output, distance)
      }
    }
  }
  output.to_bytes()
}

///|
fn write_uleb128(buffer : @buffer.Buffer, value : Int) -> Unit {
  let mut remaining = value
  while true {
    let byte_value = remaining & 0x7f
    remaining = remaining >> 7
    if remaining == 0 {
      buffer.write_byte(byte_value.to_byte())
      break
    } else {
      buffer.write_byte((byte_value | 0x80).to_byte())
    }
  }
}

///|
/// Write variable-length integer using LEB128 encoding
///
/// This function encodes integers using a variable-length format where
/// each byte contains 7 data bits and 1 continuation bit. This is more
/// space-efficient than fixed-width integers for small values.
///
/// # Parameters
/// - `buffer`: Output buffer to write to
/// - `value`: Integer value to encode (must be non-negative)
///
/// # Encoding Format
/// - Each byte: [continuation_bit][7_data_bits]
/// - Continuation bit = 1: more bytes follow
/// - Continuation bit = 0: last byte
/// - Little-endian byte order (LSB first)
///
/// # Examples
/// - 0-127: single byte (0xxxxxxx)
/// - 128-16383: two bytes (1xxxxxxx 0xxxxxxx)
/// - etc.
///
/// # Performance
/// - 1 byte for values 0-127
/// - 2 bytes for values 128-16383
/// - 3 bytes for values 16384-2097151
/// - etc.

///|
test "write_uleb128" {
  let buffer = @buffer.new()
  write_uleb128(buffer, 0)
  assert_eq(buffer.to_bytes(), b"\x00")
  buffer.reset()
  write_uleb128(buffer, 127)
  assert_eq(buffer.to_bytes(), b"\x7f")
  buffer.reset()
  write_uleb128(buffer, 128)
  assert_eq(buffer.to_bytes(), b"\x80\x01")
  buffer.reset()
  write_uleb128(buffer, 129)
  assert_eq(buffer.to_bytes(), b"\x81\x01")
  buffer.reset()
  write_uleb128(buffer, 16383)
  assert_eq(buffer.to_bytes(), b"\xff\x7f")
  buffer.reset()
  write_uleb128(buffer, 16384)
  assert_eq(buffer.to_bytes(), b"\x80\x80\x01")
  buffer.reset()
  write_uleb128(buffer, 2097151)
  assert_eq(buffer.to_bytes(), b"\xff\xff\x7f")
}
