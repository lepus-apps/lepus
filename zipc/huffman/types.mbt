// Huffman coding types and constants for DEFLATE
// RFC 1951: Fixed and Dynamic Huffman codes

// Huffman tree node for decoding

///|
pub enum HuffmanNode {
  Leaf(Int) // Symbol value (0-285 for literals/lengths, 0-29 for distances)
  Branch(HuffmanNode, HuffmanNode) // Left and right children
} derive(Debug, Eq)

///|
/// Block types for DEFLATE compression
pub enum BlockType {
  Uncompressed // No compression (BTYPE = 00)
  FixedHuffman // Compressed with fixed Huffman codes (BTYPE = 01)  
  DynamicHuffman // Compressed with dynamic Huffman codes (BTYPE = 10)
} derive(Debug, Eq)

///|
/// Convert block type to BTYPE valuef
pub fn block_type_to_btype(block_type : BlockType) -> Int {
  match block_type {
    BlockType::Uncompressed => 0
    BlockType::FixedHuffman => 1
    BlockType::DynamicHuffman => 2
  }
}

///|
/// Convert BTYPE value to block type
pub fn btype_to_block_type(btype : Int) -> BlockType? {
  match btype {
    0 => Some(BlockType::Uncompressed)
    1 => Some(BlockType::FixedHuffman)
    2 => Some(BlockType::DynamicHuffman)
    _ => None
  }
}

///|
/// Helper functions to create block types
pub fn uncompressed_block_type() -> BlockType {
  BlockType::Uncompressed
}

///|
pub fn fixed_huffman_block_type() -> BlockType {
  BlockType::FixedHuffman
}

///|
pub fn dynamic_huffman_block_type() -> BlockType {
  BlockType::DynamicHuffman
}

// RFC 1951 Constants
// let max_literal_length_codes : Int = 286  // 0-285 (for future use)
// let max_distance_codes : Int = 30         // 0-29 (for future use)
// let max_code_length_codes : Int = 19      // 0-18 (for future dynamic Huffman)

///|
let max_code_length : Int = 15 // Maximum Huffman code length

// Length base values and extra bits (RFC 1951 Section 3.2.5)

///|
let length_base : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let length_extra_bits : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 0,
]

// Distance base values and extra bits (RFC 1951 Section 3.2.5)

///|
let distance_base : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let distance_extra_bits : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

// Code length alphabet order (RFC 1951 Section 3.2.7) - for future dynamic Huffman
// let code_length_order : Array[Int] = [
//   16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
// ]
