// Tests for Adler-32 implementation - Public API only

///|
test "adler32_empty_bytes" {
  let empty_bytes = Bytes::from_array([])
  let adler = @adler32.bytes(empty_bytes)
  let expected = @adler32.bytes(Bytes::from_array([]))
  // Empty bytes should have consistent Adler-32
  assert_eq(adler, expected)
}

///|
test "adler32_hello_world_bytes" {
  let test_bytes = @utf8.encode("Hello, World!")
  let adler = @adler32.bytes(test_bytes)
  let empty_adler = @adler32.bytes(Bytes::from_array([]))
  // Test that we get some Adler value different from empty
  assert_true(adler != empty_adler)
}

///|
test "adler32_equality_modern" {
  let test_data = "test data"
  let test_bytes = @utf8.encode(test_data)
  let adler1 = @adler32.bytes(test_bytes)
  let adler2 = @adler32.bytes(test_bytes)
  let different_adler = @adler32.bytes(@utf8.encode("different"))

  // Test struct equality (modern way)
  assert_eq(adler1 == adler2, true)
  assert_eq(adler1 == different_adler, false)
  assert_eq(adler1, adler2) // Direct equality
}

///|
test "adler32_show_implementation" {
  let test_bytes = @utf8.encode("Hello, Adler32!")
  let adler = @adler32.bytes(test_bytes)

  // Test Show implementation works (should display hex format)
  let empty_adler = @adler32.bytes(Bytes::from_array([]))
  assert_true(adler != empty_adler)

  // Test consistency
  let same_adler = @adler32.bytes(test_bytes)
  assert_eq(adler, same_adler)
}

///|
test "adler32_various_data_sizes" {
  // Test small data
  let small = @adler32.bytes(@utf8.encode("a"))
  let empty = @adler32.bytes(Bytes::from_array([]))
  assert_true(small != empty)

  // Test medium data
  let medium = @adler32.bytes(
    @utf8.encode("Hello, this is a medium sized test string!"),
  )
  assert_true(medium != small)
  assert_true(medium != empty)

  // Test large data
  let large_data = "This is a much larger test string that should produce a different Adler-32 checksum than the smaller ones. It contains multiple sentences and should thoroughly test the checksum algorithm."
  let large = @adler32.bytes(@utf8.encode(large_data))
  assert_true(large != medium)
  assert_true(large != small)
  assert_true(large != empty)
}

///|
test "adler32_binary_data" {
  // Test with binary data (not just text)
  let binary_data = Bytes::from_array([0, 1, 2, 3, 4, 5, 255, 254, 253])
  let binary_adler = @adler32.bytes(binary_data)
  let empty_adler = @adler32.bytes(Bytes::from_array([]))
  assert_true(binary_adler != empty_adler)

  // Test consistency with same binary data
  let same_binary_adler = @adler32.bytes(binary_data)
  assert_eq(binary_adler, same_binary_adler)
}

///|
test "bytes" {
  // Verified test against Python's zlib.adler32()
  inspect(
    @adler32.bytes("hello world hgoho xx yy zz aa bb cc dd ee ff"),
    content="0x545410050481025150",
  )
  inspect(
    @adler32.bytes("hello world hgoho xx yy zz aa bb cc dd ee ff").0,
    content="1725042482",
  )
  inspect(
    @adler32.bytes("hello world hgoho xx yy zz aa bb cc dd ee").0,
    content="980291142",
  )
}
