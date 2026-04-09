// Copyright 2024 peter-jerry-ye
// SPDX-License-Identifier: MIT

///|
pub fn utf8(bytes : Iter[Byte]) -> Iter[Char] {
  let mut len = 0
  let mut char = 0
  Iter::new(fn() -> Char? {
    while true {
      guard bytes.next() is Some(byte) else { return None }
      let b = byte.to_int()
      if len == 0 {
        if b < 0b1000_0000 {
          return Some(Int::unsafe_to_char(b))
        } else if b < 0b1100_0000 {
          // invalid
          return None
        } else if b < 0b1110_0000 {
          char = b & 0b11111
          len = 1
        } else if b < 0b1111_0000 {
          char = b & 0b1111
          len = 2
        } else if b < 0b1111_1000 {
          char = b & 0b111
          len = 3
        } else {
          // invalid
          return None
        }
      } else if b >> 6 == 0b10 {
        char = (char << 6) | (b & 0b111111)
        len -= 1
        if len == 0 {
          return Some(Int::unsafe_to_char(char))
        }
      } else {
        // invalid
        return None
      }
    } nobreak {
      None
    }
  })
}
