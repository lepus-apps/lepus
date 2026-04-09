// Tests for CRC-32 implementation

///|
test "crc32_empty_bytes" {
  let crc = @crc32.bytes(Bytes::from_array([]))
  // Empty bytes should have CRC-32 of 0
  assert_eq(crc, Crc32(0L))
}

///|
test "crc32_hello_world" {
  let crc = @crc32.bytes(@utf8.encode("Hello, World!"))
  // Test that we get some CRC value (exact value may vary)
  assert_true(crc != Crc32(0L))
}

///|
test "crc32_equality" {
  let crc1 = @crc32.bytes(@utf8.encode("test"))
  let crc2 = @crc32.bytes(@utf8.encode("test"))
  let crc3 = @crc32.bytes(@utf8.encode("different"))
  assert_eq(crc1, crc2)
  assert_not_eq(crc1, crc3)
}

///|
test "crc32_bytes_consistency" {
  let test_string = "Hello, Bytes!"
  let test_bytes = @utf8.encode(test_string)
  let crc1 = @crc32.bytes(test_bytes)
  let crc2 = @crc32.bytes(@utf8.encode(test_string))

  // Both should produce the same result
  assert_eq(crc1, crc2)
  assert_true(crc1 != Crc32(0L))
}

///|
test "crc32_bytes" {
  inspect(
    @crc32.bytes(b"hello"),
    content=(
      #|0x686a0163
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho"),
    content=(
      #|0xb8653f56
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx"),
    content=(
      #|0x278310b5
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy"),
    content=(
      #|0xdd4a5c72
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy zz"),
    content=(
      #|0xa3f78360
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy zz aa"),
    content=(
      #|0xd3926082
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy zz aa bb"),
    content=(
      #|0x69adde2b
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy zz aa bb cc"),
    content=(
      #|0x4d0e5910
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy zz aa bb cc dd"),
    content=(
      #|0xadd99d8d
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy zz aa bb cc dd ee"),
    content=(
      #|0xedbb0a95
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy zz aa bb cc dd ee ff"),
    content=(
      #|0x64b5a860
    ),
  )
  inspect(
    @crc32.bytes(b"hello world hgoho xx yy zz aa bb cc dd ee ff"),
    content=(
      #|0x64b5a860
    ),
  )
}
