# LZ77 Compression Package

A comprehensive implementation of the LZ77 sliding window compression algorithm for MoonBit.

## Overview

LZ77 is a lossless data compression algorithm that uses a sliding window to find and replace repeated occurrences of data with references to previous occurrences. This implementation provides both encoding and decoding capabilities with configurable parameters.

## Features

- **High-Performance Encoding**: Hash-based string matching for efficient compression
- **Robust Decoding**: Handles overlapping references correctly
- **Configurable Parameters**: Customizable window size, match lengths, and distances
- **DEFLATE Compatible**: Default configuration matches DEFLATE requirements
- **Comprehensive Testing**: Full test suite with edge cases and performance tests
- **Error Handling**: Proper validation and error reporting

## Basic Usage

### Encoding Data

```moonbit nocheck
///|
test {
  // Basic encoding with default configuration
  let data = "Hello World Hello World".to_bytes()
  let tokens = @lz77.encode_default(data)
  inspect(tokens.length() > 0, content="true")

  // Custom configuration
  let config = @lz77.default_config()
  let custom_tokens = @lz77.encode(data, config)
  inspect(custom_tokens.length() > 0, content="true")
}
```

### Decoding Data

```moonbit nocheck
///|
test {
  // Decode tokens back to original data
  let data = "Hello World".to_bytes()
  let tokens = @lz77.encode_default(data)
  let decoded = @lz77.decode(tokens)
  inspect(decoded == data, content="true")
}
```

### Byte Format Encoding/Decoding

```moonbit nocheck
///|
test {
  // Encode to byte format for storage/transmission
  let data = "Hello World".to_bytes()
  let compressed = @lz77.encode_to_bytes(data, @lz77.default_config())

  // Decode from byte format
  let decompressed = @lz77.decode_from_bytes(compressed)
  inspect(decompressed == data, content="true")
}
```

## API Reference

### Types

#### `LZ77Token`
Represents a compression token:
- `Literal(Byte)`: A single literal byte
- `Reference(Int, Int)`: A back-reference with (length, distance)

#### `LZ77Config`
Configuration parameters:
- `window_size`: Size of the sliding window (default: 32768)
- `max_match_length`: Maximum match length (default: 258)
- `min_match_length`: Minimum match length (default: 3)
- `max_distance`: Maximum back-reference distance (default: 32768)

### Functions

#### Encoding
- `encode(data: Bytes, config: LZ77Config) -> Array[LZ77Token]`
- `encode_default(data: Bytes) -> Array[LZ77Token]`
- `encode_to_bytes(data: Bytes, config: LZ77Config) -> Bytes`

#### Decoding
- `decode(tokens: Array[LZ77Token]) -> Bytes`
- `decode_from_bytes(data: Bytes) -> Bytes`

#### Utilities
- `validate_tokens(tokens: Array[LZ77Token]) -> Bool`
- `get_compression_stats(original_size: Int, tokens: Array[LZ77Token]) -> (Int, Int, Double)`
- `default_config() -> LZ77Config`

## Algorithm Details

### Encoding Process

1. **Sliding Window**: Maintains a window of recently processed data
2. **Hash Table**: Uses hash chains for fast string matching
3. **Match Finding**: Searches for the longest match within the window
4. **Token Generation**: Outputs either literals or length-distance pairs

### Decoding Process

1. **Token Processing**: Processes tokens sequentially
2. **Literal Handling**: Directly outputs literal bytes
3. **Reference Handling**: Copies data from previous positions
4. **Overlap Handling**: Correctly handles overlapping references

### Hash Function

Uses a 3-byte rolling hash for efficient string matching:
```
hash = ((b1 << 10) ^ (b2 << 5) ^ b3) % hash_size
```

## Performance Characteristics

- **Time Complexity**: O(n) average case for encoding
- **Space Complexity**: O(window_size) for hash tables
- **Compression Ratio**: Depends on data redundancy, typically 30-70% for text

## Integration with DEFLATE

This LZ77 implementation is designed to be compatible with DEFLATE compression:

```moonbit nocheck
///|
test {
  // DEFLATE-compatible configuration
  let deflate_config = @lz77.default_config() // Already DEFLATE-compatible
  inspect(deflate_config.window_size, content="32768")
}
```

## Testing

Run the comprehensive test suite:

```bash
moon test lz77
```

The test suite includes:
- Basic functionality tests
- Edge case handling
- Performance benchmarks
- Error condition testing
- Compression statistics validation

## Examples

### Text Compression

```moonbit nocheck
///|
test {
  let text = "The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog."
  let data = text.to_bytes()

  let compressed = @lz77.encode_to_bytes(data, @lz77.default_config())
  let decompressed = @lz77.decode_from_bytes(compressed)

  inspect(decompressed == data, content="true")

  let (_literals, _references, ratio) = @lz77.get_compression_stats(
    data.length(),
    @lz77.encode_default(data),
  )
  println("Compression ratio: " + ratio.to_string())
}
```

### Pattern Detection

```moonbit nocheck
///|
test {
  // Create data with repeating patterns
  let pattern_data = @buffer.new()
  for i = 0; i < 100; i = i + 1 {
    pattern_data.write_byte((i % 10 + 48).to_byte()) // "0123456789" repeated
  }

  let tokens = @lz77.encode_default(pattern_data.to_bytes())
  let decoded = @lz77.decode(tokens)

  inspect(decoded == pattern_data.to_bytes(), content="true")
  inspect("Pattern detection works", content="Pattern detection works")
}
```

## Error Handling

The implementation includes comprehensive error handling:

- **Invalid References**: Validates distance and length parameters
- **Malformed Data**: Detects corrupted compressed data
- **Boundary Checks**: Prevents buffer overruns
- **Configuration Validation**: Ensures valid parameters

## Future Enhancements

- **Lazy Matching**: Implement lazy evaluation for better compression
- **Multiple Hash Functions**: Support different hash strategies
- **Streaming Interface**: Support for streaming compression/decompression
- **Memory Optimization**: Reduce memory usage for large windows

## License

This implementation is part of the MoonBit zipc library and follows the same licensing terms.
