# Huffman Coding Package

This package provides essential Huffman coding functionality for DEFLATE compression as specified in RFC 1951. It exposes a minimal, clean interface focused on block type management and Fixed Huffman decompression.

## Features

- **Block Type Management**: DEFLATE block type definitions and conversions
- **Fixed Huffman Decompression**: Bytes-based Fixed Huffman block decompression
- **Minimal Interface**: Only essential functions are exposed publicly

## Usage

```moonbit nocheck
///|
test "huffman_minimal_interface_example" {
  // Block type management - the core public API
  let uncompressed = @huffman.uncompressed_block_type()
  let fixed_huffman = @huffman.fixed_huffman_block_type()
  let dynamic_huffman = @huffman.dynamic_huffman_block_type()

  // Convert block types to BTYPE values
  let btype0 = @huffman.block_type_to_btype(uncompressed)
  let btype1 = @huffman.block_type_to_btype(fixed_huffman)
  let btype2 = @huffman.block_type_to_btype(dynamic_huffman)

  inspect(btype0, content="0")
  inspect(btype1, content="1")
  inspect(btype2, content="2")

  // Convert BTYPE values back to block types
  match @huffman.btype_to_block_type(1) {
    Some(block_type) =>
      if block_type == @huffman.fixed_huffman_block_type() {
        inspect(
          "Fixed Huffman block type correctly identified",
          content="Fixed Huffman block type correctly identified",
        )
      }
    None => fail("Should have found block type")
  }
}
```

## Block Types

The package defines DEFLATE block types:

- `Uncompressed`: No compression (BTYPE = 00)
- `FixedHuffman`: Fixed Huffman codes (BTYPE = 01)
- `DynamicHuffman`: Dynamic Huffman codes (BTYPE = 10)

## Public API

The package exposes only the essential functions needed for DEFLATE compression:

### Block Type Management
- `uncompressed_block_type()` - Create uncompressed block type
- `fixed_huffman_block_type()` - Create fixed Huffman block type  
- `dynamic_huffman_block_type()` - Create dynamic Huffman block type
- `block_type_to_btype(BlockType)` - Convert block type to BTYPE integer
- `btype_to_block_type(Int)` - Convert BTYPE integer to block type

### Fixed Huffman Decompression
- `decompress_fixed_huffman_block_bytes(Bytes, Int)` - Decompress Fixed Huffman blocks

## Implementation Status

- ✅ **Block Type Management**: Complete and stable
- ✅ **Minimal Interface**: Clean, focused API
- 🚧 **Fixed Huffman Decompression**: Placeholder implementation
- ❌ **Dynamic Huffman Support**: Not yet implemented

## Design Philosophy

This package follows the principle of **minimal interface exposure**:
- Only functions actually needed by the deflate module are public
- Internal implementation details are hidden
- Clean separation between public API and internal utilities
- Easy to extend without breaking existing code

## Dependencies

- `moonbitlang/core/bytes`: For binary data handling

## License

This package is part of the MoonBit ZIP library and follows the same license terms.
