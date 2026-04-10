// Simple snapshot tests for ZIP API

///|
test "empty archive properties" {
  let archive = @zipc.Archive::new()

  // Snapshot: Empty archive properties
  inspect(archive.member_count(), content="0")
  inspect(archive.is_empty(), content="true")
  inspect(archive.mem("nonexistent.txt"), content="false")
}

///|
test "empty archive encoding" {
  let archive = @zipc.Archive::new()
  let zip_data = archive.to_bytes()

  // Snapshot: Empty ZIP should be exactly 22 bytes
  inspect(zip_data.length(), content="22")

  // Test roundtrip
  let decoded = @zipc.of_binary(zip_data)
  inspect(decoded.is_empty(), content="true")
  inspect(decoded.member_count(), content="0")
  ignore(decoded)
}

///|
test "error handling basic" {
  // Test invalid ZIP data - should raise error
  try {
    ignore(@zipc.of_binary(@utf8.encode("Not a ZIP file")))
    fail("Should have failed on invalid ZIP data")
  } catch {
    error =>
      inspect(
        error,
        content=(
          #|Failure("zipc/zip.mbt:599:5-599:53@lepus-apps/lepus FAILED: File too small to be a valid ZIP archive")
        ),
      )
  }

  // Test empty data - should raise error
  try {
    ignore(@zipc.of_binary(Bytes::from_array([])))
    fail("Should have failed on empty data")
  } catch {
    error =>
      inspect(
        error,
        content=(
          #|Failure("zipc/zip.mbt:599:5-599:53@lepus-apps/lepus FAILED: File too small to be a valid ZIP archive")
        ),
      )
  }
}

///|
test "compression levels api" {
  let test_data = "Test data for levels"

  // Verify test data is not empty
  inspect(test_data.length() > 0, content="true")
  // Test compression with different levels
  let compressed_none = @zipc.File::deflate_of_binary_string(test_data, None)
  // Snapshot: Should produce compressed file
  inspect(compressed_none.compressed_size() > 0, content="true")

  let compressed_fast = @zipc.File::deflate_of_binary_string(test_data, Fast)
  // Snapshot: Should produce compressed file
  inspect(compressed_fast.compressed_size() > 0, content="true")

  // Test default and best levels as well
  let compressed_default = @zipc.File::deflate_of_binary_string(
    test_data,
    Default,
  )
  // Snapshot: Should produce compressed file
  inspect(compressed_default.compressed_size() > 0, content="true")

  let compressed_best = @zipc.File::deflate_of_binary_string(test_data, Best)
  // Snapshot: Should produce compressed file
  inspect(compressed_best.compressed_size() > 0, content="true")
}
