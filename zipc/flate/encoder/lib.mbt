// Copyright 2024 peter-jerry-ye
// SPDX-License-Identifier: MIT

///|
pub fn utf8(string : Iter[Char]) -> Iter[Byte] {
  let buf : Array[Byte] = [0, 0, 0]
  let mut view = buf[0:0]
  Iter::new(fn() -> Byte? {
    if view.length() > 0 {
      let next_byte = view[0]
      view = view[1:view.length()]
      return Some(next_byte)
    }
    guard string.next() is Some(char) else { None }
    let point = char.to_int()
    if point < 0x80 {
      Some((((point >> 0) & 0x7F) | 0x00).to_byte())
    } else if point < 0x0800 {
      let next_byte = (((point >> 6) & 0x1F) | 0xC0).to_byte()
      buf[0] = (((point >> 0) & 0x3F) | 0x80).to_byte()
      view = buf[0:1]
      Some(next_byte)
    } else if point < 0x10000 {
      let next_byte = (((point >> 12) & 0x0F) | 0xE0).to_byte()
      buf[0] = (((point >> 6) & 0x3F) | 0x80).to_byte()
      buf[1] = (((point >> 0) & 0x3F) | 0x80).to_byte()
      view = buf[0:2]
      Some(next_byte)
    } else {
      let next_byte = (((point >> 18) & 0x07) | 0xF0).to_byte()
      buf[0] = (((point >> 12) & 0x3F) | 0x80).to_byte()
      buf[1] = (((point >> 6) & 0x3F) | 0x80).to_byte()
      buf[2] = (((point >> 0) & 0x3F) | 0x80).to_byte()
      view = buf[0:3]
      Some(next_byte)
    }
  })
}
