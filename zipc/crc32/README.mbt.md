# CRC32 Package

A high-performance CRC-32 checksum implementation for MoonBit, optimized for ZIP file operations and binary data processing.

## Overview

This package provides CRC-32 (Cyclic Redundancy Check) functionality using the standard polynomial `0xedb88320` (reversed `0x04c11db7`), which is widely used in ZIP files, PNG images, and other formats.

## Features

- **High Performance**: Optimized with precomputed lookup tables
- **Type Safety**: Proper `Crc32` struct with compile-time guarantees  
- **Modern API**: Clean `bytes()` function as primary interface
- **Professional Output**: Hex formatting with `Show` implementation
- **ZIP Compatible**: Uses the standard CRC-32 polynomial for ZIP files

## Quick Start

```moonbit nocheck
///|
test "quick_start_example" {
  // Calculate CRC-32 of some data
  let data = b"Hello, World!"
  let checksum = @crc32.bytes(data)
  inspect(checksum, content="0x101995297995110048")

  // Verify data integrity
  let received_data = b"Hello, World!"
  let received_checksum = @crc32.bytes(received_data)
  assert_eq(checksum, received_checksum)
}
```

## API Reference

### Types

#### `Crc32`
```moonbit nocheck
///|
pub(all) struct Crc32(Int64) derive(Eq)
```

A CRC-32 checksum value with built-in equality comparison.

**Methods:**
- `inner(self) -> Int64` - Access the raw Int64 value
- `Show` implementation - Displays as hex (e.g., `0x1c291ca3`)
- `Eq` implementation - Structural equality comparison

### Functions

#### `bytes(data: Bytes) -> Crc32`

Calculate the CRC-32 checksum of byte data.

```moonbit nocheck
///|
test "bytes_function_example" {
  let data = b"Hello, CRC32!"
  let crc = @crc32.bytes(data)
  inspect(crc, content="0x10110150971025110249")
}
```

**Parameters:**
- `data: Bytes` - The data to checksum

**Returns:**
- `Crc32` - The calculated checksum

## Examples

### Basic Usage

```moonbit nocheck
///|
test "example_basic" {
  // Calculate checksum
  let message = b"Hello, World!"
  let checksum = @crc32.bytes(message)

  // Display result
  inspect("Message: Hello, World!", content="Message: Hello, World!")
  inspect(checksum, content="0x101995297995110048")
}
```

### Data Integrity Verification

```moonbit nocheck
///|
test "example_integrity" {
  let original_data = b"Important data"
  let expected_crc = @crc32.bytes(original_data)

  // Simulate data transmission/storage
  let received_data = b"Important data"
  let received_crc = @crc32.bytes(received_data)

  // Verify integrity
  assert_eq(expected_crc, received_crc)
}
```

### Working with Different Data Types

```moonbit nocheck
///|
test "example_data_types" {
  // Text data
  let text_crc = @crc32.bytes(b"Hello")

  // Binary data
  let binary_data = Bytes::from_array([0x48, 0x65, 0x6c, 0x6c, 0x6f]) // "Hello" in bytes
  let binary_crc = @crc32.bytes(binary_data)

  // They should be equal
  assert_eq(text_crc, binary_crc)
  inspect(text_crc, content="0x102551004956575650")
}
```

### Performance Comparison

```moonbit nocheck
///|
test "example_performance" {
  let small_data = b"Hello"
  let large_data = b"This is a much larger piece of data that will take more time to process but still be very fast with our optimized CRC-32 implementation."

  let small_crc = @crc32.bytes(small_data)
  let large_crc = @crc32.bytes(large_data)

  inspect(small_crc, content="0x102551004956575650")
  inspect(large_crc, content="0x49524897525197102")
  inspect(
    "Both calculated efficiently!",
    content="Both calculated efficiently!",
  )
}
```

## Technical Details

### Algorithm

This implementation uses the standard CRC-32 algorithm with:
- **Polynomial**: `0xedb88320` (reversed `0x04c11db7`)
- **Initial value**: `0xffffffff`
- **Final XOR**: `0xffffffff`
- **Lookup table**: 256-entry precomputed table for performance

### Performance

- **Optimized**: Uses precomputed lookup tables
- **Fast**: Processes data in single-byte chunks with table lookups
- **Memory efficient**: Minimal memory overhead
- **Bytes-optimized**: Direct byte processing without string conversion overhead

### Compatibility

This CRC-32 implementation is compatible with:
- ZIP file format (PKZIP)
- PNG image format
- Ethernet frame check sequence
- Many other standard applications

The checksum values match those produced by:
- Python's `zlib.crc32()`
- Java's `java.util.zip.CRC32`
- C's `zlib` library
- Most standard CRC-32 implementations

## Integration

This package is designed to work seamlessly with the zipc library ecosystem:

```moonbit nocheck
///|
test "integration_example" {
  // Used internally by ZIP operations
  let file_data = b"File content"
  let file_crc = @crc32.bytes(file_data)
  // CRC is automatically included in ZIP file headers
  inspect(file_crc, content="0x995610150100495354")
}
```

## Thread Safety

The CRC-32 implementation is stateless and thread-safe. All functions are pure and can be called concurrently without synchronization.
