// This file is based on the Go implementation found here:
// https://cs.opensource.google/go/go/+/refs/tags/go1.23.1:src/compress/flate/deflate.go
// which has the copyright notice:
// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

///|
const LOG_WINDOW_SIZE = 15

///|
let window_size : Int = 1 << LOG_WINDOW_SIZE

///|
let window_mask : Int = window_size - 1

// The smallest match length that the compressor actually emits

///|
const MIN_MATCH_LENGTH = 4

// The largest match length

///|
const MAX_MATCH_LENGTH = 258

// The maximum number of tokens we put into a single flate block, just to
// stop things from getting too large.

// let max_flate_block_tokens : Int = 1 << 14

// const MAX_STORE_BLOCK_SIZE = 65535

///|
const HASH_BITS = 17 // After 17 performance degrades

///|
let hash_size : Int = 1 << HASH_BITS

///|
let hash_mask : UInt = (1U << HASH_BITS) - 1

// let max_hash_offset : Int = 1 << 24

///|
priv struct Compressor {
  w : HuffmanBitWriter

  // compression algorithm
  best_speed : DeflateFast // Encoder for best_speed

  // Input hash chains
  // hashHead[hashValue] contains the largest inputIndex with the specified hash value
  // If hashHead[hashValue] is within the current window, then
  // hashPrev[hashHead[hashValue] & windowMask] contains the previous index
  // with the same hash value.
  // chain_head : Int
  hash_head : Slice[UInt] // [hash_size]uint32
  hash_prev : Slice[UInt] // [window_size]uint32
  hash_offset : Int

  // input window: unprocessed data is window[:window_end]
  window : Slice[Byte]
  mut window_end : Int
  mut sync : Bool // requesting flush

  // queued output tokens
  mut tokens : Array[Token]

  // deflate state
  // mut length : Int
  // mut offset : Int
  // mut max_insert_index : Int
  mut err : IOError?

  // hash_match must be able to contain hashes for the maximum match length.
  hash_match : Slice[UInt] //  [maxMatchLength - 1]uint32
}

///|
fn Compressor::new(buf : &@io.Writer) -> Compressor {
  let w = HuffmanBitWriter::new(buf)
  {
    w,
    // chain_head: 0,
    hash_head: Slice::new(Array::make(hash_size, 0)),
    hash_prev: Slice::new(Array::make(window_size, 0)),
    hash_offset: 0,
    window: Slice::new(Array::make(max_store_block_size, b'\x00')),
    window_end: 0,
    sync: false,
    best_speed: DeflateFast::new(),
    tokens: Array::make(max_store_block_size, 0),
    // length: 0,
    // offset: 0,
    // max_insert_index: 0,
    err: None,
    hash_match: Slice::new(Array::make(MAX_MATCH_LENGTH - 1, 0)),
  }
}

// fill_window will fill the current window with the supplied
// dictionary and calculate all hashes.
// This is much faster than doing a full encode.
// Should only be used after a reset.

///|
fn Compressor::fill_window(self : Compressor, b : Slice[Byte]) -> Unit {
  // if self.index != 0 || self.window_end != 0 {
  if self.window_end != 0 {
    abort("internal error: fill_window called with stale data")
  }

  // If we are given too much, cut it.
  let mut b = b
  if b.length() > window_size {
    b = b[b.length() - window_size:]
  }
  // Add all to window.
  let n = slice_copy(self.window, b)

  // Calculate 256 hashes at the time (more L1 cache hits)
  let loops = (n + 256 - MIN_MATCH_LENGTH) / 256
  for j = 0; j < loops; j = j + 1 {
    let index = j * 256
    let mut end = index + 256 + MIN_MATCH_LENGTH - 1
    if end > n {
      end = n
    }
    let to_check = self.window[index:end]
    let dst_size = to_check.length() - MIN_MATCH_LENGTH + 1
    if dst_size <= 0 {
      continue
    }
    let dst = self.hash_match[:dst_size]
    bulk_hash4(to_check, dst)
    for i, val in dst {
      let di = i + index
      let hh_index = (val & hash_mask).reinterpret_as_int()
      let hh = self.hash_head[hh_index]
      // Get previous value with the same hash.
      // Our chain should point to the previous value.
      self.hash_prev[di & window_mask] = hh
      // Set the head of the hash chain to us.
      self.hash_head[hh_index] = (di + self.hash_offset).reinterpret_as_uint()
    }
  }
  // Update window information.
  self.window_end = n
  // self.index = n
}

///|
pub let writer_closed_error : @io.IOError = @io.IOError("writer closed")

///|
fn Compressor::close(self : Compressor) -> IOError? {
  if Some(writer_closed_error) == self.err {
    return None
  }
  match self.err {
    Some(_) => return self.err
    _ => ()
  }
  self.sync = true
  self.enc_speed()
  match self.err {
    Some(_) => return self.err
    _ => ()
  }
  self.w.write_stored_header(0, true)
  match self.w.err {
    Some(_) => return self.w.err
    _ => ()
  }
  self.w.flush()
  match self.w.err {
    Some(_) => return self.w.err
    _ => ()
  }
  self.err = Some(writer_closed_error)
  None
}

///|
fn Compressor::write_stored_block(
  self : Compressor,
  buf : Slice[Byte],
) -> IOError? {
  self.w.write_stored_header(buf.length(), false)
  if !(self.w.err is None) {
    return self.w.err
  }
  self.w.write_bytes(buf)
  return self.w.err
}

///|
const HASHMUL = 0x1e35a7bdU

// bulk_hash4 will compute hashes using the same
// algorithm as hash4.

///|
fn bulk_hash4(b : Slice[Byte], dst : Slice[UInt]) -> Unit {
  if b.length() < MIN_MATCH_LENGTH {
    return
  }
  let mut hb = b[3].to_uint() |
    (b[2].to_uint() << 8) |
    (b[1].to_uint() << 16) |
    (b[0].to_uint() << 24)
  dst[0] = (hb * HASHMUL) >> (32 - HASH_BITS)
  let end = b.length() - MIN_MATCH_LENGTH + 1
  for i = 1; i < end; i = i + 1 {
    hb = (hb << 8) | b[i + 3].to_uint()
    dst[i] = (hb * HASHMUL) >> (32 - HASH_BITS)
  }
}

///|
fn Compressor::fill_store(self : Compressor, b : Slice[Byte]) -> Int {
  let n = minimum(self.window.length() - self.window_end, b.length())
  for i in 0..<n {
    self.window[self.window_end + i] = b[i]
  }
  self.window_end += n
  n
}

// encSpeed will compress and store the currently added data,
// if enough has been accumulated or we at the end of the stream.
// Any error that occurred will be in self.err

///|
fn Compressor::enc_speed(self : Compressor) -> Unit {
  // We only compress if we have max_store_block_size.
  if self.window_end < max_store_block_size {
    if !self.sync {
      return
    }

    // Handle small sizes.
    if self.window_end < 128 {
      if self.window_end == 0 {
        return
      }
      if self.window_end <= 16 {
        self.err = self.write_stored_block(self.window[:self.window_end])
      } else {
        self.w.write_block_huff(false, self.window[:self.window_end])
        self.err = self.w.err
      }
      self.window_end = 0
      self.best_speed.reset()
      return
    }
  }
  // Encode the block.
  self.tokens = self.best_speed.encode(
    Array::new(capacity=self.window_end),
    self.window[:self.window_end],
  )

  // If we removed less than 1/16th, Huffman compress the block.
  if self.tokens.length() > self.window_end - (self.window_end >> 4) {
    self.w.write_block_huff(false, self.window[:self.window_end])
  } else {
    self.w.write_block_dynamic(
      self.tokens,
      false,
      self.window[:self.window_end],
    )
  }
  self.err = self.w.err
  self.window_end = 0
}

///|
fn Compressor::write(self : Compressor, b : Slice[Byte]) -> (Int, IOError?) {
  if !(self.err is None) {
    return (0, self.err)
  }
  let mut b = b
  let n = b.length()
  while b.length() > 0 {
    self.enc_speed()
    b = b[self.fill_store(b):]
    if !(self.err is None) {
      return (0, self.err)
    }
  }
  (n, None)
}


