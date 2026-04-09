// Copyright 2024 peter-jerry-ye
// SPDX-License-Identifier: MIT

///|
struct TestCase {
  name : String
  input : Array[Byte]
  expected : Array[Char]
}

///|
test "utf8" {
  let tests : Array[TestCase] = [
    { name: "empty", input: [], expected: [] },
    { name: "ascii_single", input: [b'a'], expected: ['a'] },
    {
      name: "ascii_multiple",
      input: [b'a', b'b', b'c'],
      expected: ['a', 'b', 'c'],
    },
    { name: "two_byte", input: [0xc3, 0xa9], expected: ['é'] },
    { name: "three_byte", input: [0xe2, 0x99, 0xa5], expected: ['♥'] },
    { name: "four_byte", input: [0xf0, 0x9f, 0x98, 0x80], expected: ['😀'] },
    { name: "invalid_start", input: [0x80], expected: [] },
    { name: "incomplete_two_byte", input: [0xc3], expected: [] },
    { name: "incomplete_three_byte", input: [0xe2, 0x99], expected: [] },
    { name: "invalid_continuation", input: [0xc3, 0x00], expected: [] },
    {
      name: "overlong",
      input: [0xc0, 0x80],
      expected: [Int::unsafe_to_char(0)],
    },
    {
      name: "mixed_valid",
      input: [b'a', 0xc3, 0xa9, b'b'],
      expected: ['a', 'é', 'b'],
    },
    { name: "invalid_in_middle", input: [b'a', 0x80, b'b'], expected: ['a'] },
  ]
  let mut failed = false
  let mut output = ""
  for tt in tests {
    let result = @decoder.utf8(tt.input.iter()).collect()
    if result != tt.expected {
      output = "Test \{tt.name} failed: expected \{tt.expected}, got \{result}"
      failed = true
      break
    } else {
      // pass
    }
  }
  if failed {
    inspect(output)
  } else {
    "All tests passed" |> inspect(content="All tests passed")
  }
}
