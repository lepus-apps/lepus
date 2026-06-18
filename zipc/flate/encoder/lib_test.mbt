// Copyright 2024 peter-jerry-ye
// SPDX-License-Identifier: MIT

///|
struct TestCase {
  name : String
  input : String
  expected : Array[Byte]
}

///|
test "utf8" {
  let tests : Array[TestCase] = [
    { name: "empty", input: "", expected: [] },
    { name: "ascii_single", input: "a", expected: [b'a'] },
    { name: "ascii_multiple", input: "abc", expected: [b'a', b'b', b'c'] },
    { name: "two_byte", input: "é", expected: [0xc3, 0xa9] },
    { name: "three_byte", input: "♥", expected: [0xe2, 0x99, 0xa5] },
    { name: "four_byte", input: "😀", expected: [0xf0, 0x9f, 0x98, 0x80] },
    {
      name: "chinese",
      input: "中文",
      expected: [0xe4, 0xb8, 0xad, 0xe6, 0x96, 0x87],
    },
    {
      name: "hearts",
      input: "❤♥",
      expected: [0xe2, 0x9d, 0xa4, 0xe2, 0x99, 0xa5],
    },
    {
      name: "mixed",
      input: "aé♥",
      expected: [b'a', 0xc3, 0xa9, 0xe2, 0x99, 0xa5],
    },
  ]
  for tt in tests {
    let result = @encoder.utf8(tt.input.iter()).collect()
    @debug.assert_eq(result, tt.expected, msg="Test " + tt.name + " failed")
  }
  "All tests passed" |> inspect(content="All tests passed")
}
