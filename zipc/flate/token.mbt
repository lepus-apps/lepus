// This file is based on the Go implementation found here:
// https://cs.opensource.google/go/go/+/refs/tags/go1.23.1:src/compress/flate/token.go
// which has the copyright notice:
// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// 2 bits:   type   0 = literal  1=EOF  2=Match   3=Unused
// 8 bits:   xlength = length - MIN_MATCH_LENGTH
// 22 bits   xoffset = offset - MIN_OFFSET_SIZE, or literal

///|
let length_shift = 22

///|
let offset_mask : UInt = (1U << length_shift) - 1

// let type_mask : Int = 3 << 30

///|
let literal_type : UInt = 0U << 30

///|
let match_type : UInt = 1U << 30

// The length code for length X (MIN_MATCH_LENGTH <= X <= MAX_MATCH_LENGTH)
// is length_codes[length - MIN_MATCH_LENGTH]

///|
let length_codes : Array[Int] = [ // Array[UInt] // Values are always used for indexing, so make them Int
  0, 1, 2, 3, 4, 5, 6, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 12, 12, 13, 13, 13,
  13, 14, 14, 14, 14, 15, 15, 15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 17, 17, 17,
  17, 17, 17, 17, 17, 18, 18, 18, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19, 19,
  19, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 21, 21, 21,
  21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 22, 22, 22, 22, 22, 22, 22,
  22, 22, 22, 22, 22, 22, 22, 22, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23,
  23, 23, 23, 23, 23, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
  24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 25, 25, 25,
  25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
  25, 25, 25, 25, 25, 25, 25, 25, 25, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
  26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
  26, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
  27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 27, 28,
]

///|
let offset_codes : Array[Int] = [ // Array[UInt] // Values are always used for indexing, so make them Int
  0, 1, 2, 3, 4, 4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 8, 9, 9, 9,
  9, 9, 9, 9, 9, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
  11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 12, 12, 12, 12,
  12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
  12, 12, 12, 12, 12, 12, 12, 12, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
  13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
  14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
  14, 14, 14, 14, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
  15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
  15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
  15, 15, 15, 15, 15, 15, 15, 15,
]

///|
priv struct Token(UInt)

// Convert a literal into a literal token.

///|
fn literal_token(literal : UInt) -> Token {
  literal_type + literal
}

// Convert a < xlength, xoffset > pair into a match token.

///|
fn match_token(xlength : UInt, xoffset : UInt) -> Token {
  match_type + (xlength << length_shift) + xoffset
}

// Returns the literal of a literal token.

///|
fn Token::literal(self : Token) -> UInt {
  self.0 - literal_type
}

// Returns the extra offset of a match token.

///|
fn Token::offset(self : Token) -> UInt {
  self.0 & offset_mask
}

///|
test "offset behaves correctly" {
  let token = Token(2143289471U)
  let got = token.offset()
  inspect(got, content="127")
}

///|
fn Token::length(self : Token) -> UInt {
  (self.0 - match_type) >> length_shift
}

///|
fn length_code(len : UInt) -> Int { // -> UInt // Values are always used for indexing, so make them Int
  length_codes[len.reinterpret_as_int()]
}

///|
fn offset_code(off : UInt) -> Int { // -> UInt // Values are always used for indexing, so make them Int
  if off < offset_codes.length().reinterpret_as_uint() {
    let idx = off.reinterpret_as_int()
    return offset_codes[idx]
  }
  if off >> 7 < offset_codes.length().reinterpret_as_uint() {
    let idx = (off >> 7).reinterpret_as_int()
    return offset_codes[idx] + 14
  }
  let idx = (off >> 14).reinterpret_as_int()
  offset_codes[idx] + 28
}
