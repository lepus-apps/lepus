// Core types for deflate module

// Compression levels

///|
pub(all) enum Level {
  None // Only non-compressed blocks
  Fast
  Default
  Best
} derive(Debug)
