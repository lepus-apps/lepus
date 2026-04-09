// LZ77 compression algorithm types and constants
// Implements the LZ77 sliding window compression scheme

// LZ77 token representing either a literal byte or a length-distance pair

///|
pub enum LZ77Token {
  Literal(Byte) // Single literal byte
  Reference(Int, Int) // (length, distance) back-reference
} derive(Debug, Eq, ToJson)

// LZ77 compression parameters

///|
pub(all) struct LZ77Config {
  window_size : Int // Size of the sliding window (typically 32KB for DEFLATE)
  max_match_length : Int // Maximum match length (typically 258 for DEFLATE)
  min_match_length : Int // Minimum match length (typically 3 for DEFLATE)
  max_distance : Int // Maximum back-reference distance
} derive(Debug, Eq)

// Default LZ77 configuration compatible with DEFLATE

///|
pub fn default_config() -> LZ77Config {
  {
    window_size: 32768, // 32KB sliding window
    max_match_length: 258, // DEFLATE max length
    min_match_length: 3, // DEFLATE min length
    max_distance: 32768, // DEFLATE max distance
  }
}

// LZ77 encoder state

///|
struct EncoderState {
  mut position : Int // Current position in input
  mut window_start : Int // Start of sliding window
  hash_table : Array[Int] // Hash table for fast string matching
  hash_head : Array[Int] // Hash chain heads
  hash_prev : Array[Int] // Hash chain previous pointers
} derive(Debug)

// LZ77 decoder state

///|
struct DecoderState {
  mut position : Int // Current position in output
  output_buffer : @buffer.Buffer // Output buffer for decoded data
} derive(Debug)

// Hash table size (power of 2 for efficient modulo)

///|
let hash_size : Int = 8192

// Hash function for 3-byte sequences

///|
pub fn hash3(b1 : Byte, b2 : Byte, b3 : Byte) -> Int {
  let h1 = b1.to_int()
  let h2 = b2.to_int()
  let h3 = b3.to_int()
  ((h1 << 10) ^ (h2 << 5) ^ h3) % hash_size
}

// Create new encoder state

///|
pub fn new_encoder_state(config : LZ77Config) -> EncoderState {
  {
    position: 0,
    window_start: 0,
    hash_table: Array::make(hash_size, -1),
    hash_head: Array::make(hash_size, -1),
    hash_prev: Array::make(config.window_size, -1),
  }
}

// Create new decoder state

///|
pub fn new_decoder_state() -> DecoderState {
  { position: 0, output_buffer: @buffer.new() }
}
