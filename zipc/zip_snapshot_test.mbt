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
  match archive.to_bytes() {
    @deflate.Ok(zip_data) => {
      // Snapshot: Empty ZIP should be exactly 22 bytes
      inspect(zip_data.length(), content="22")

      // Test roundtrip
      match @zipc.of_binary(zip_data) {
        @deflate.Ok(decoded) => {
          inspect(decoded.is_empty(), content="true")
          inspect(decoded.member_count(), content="0")
        }
        @deflate.Err(error) => fail("Empty ZIP decoding failed: " + error)
      }
    }
    @deflate.Err(error) => fail("Empty ZIP encoding failed: " + error)
  }
}

///|
test "error handling basic" {
  // Test invalid ZIP data
  match @zipc.of_binary(@utf8.encode("Not a ZIP file")) {
    @deflate.Ok(_) => fail("Should have failed on invalid ZIP data")
    @deflate.Err(error) =>
      // Snapshot: Should mention magic bytes - test the error message
      inspect(error, content="File too small to be a valid ZIP archive")
  }

  // Test empty data
  match @zipc.of_binary(Bytes::from_array([])) {
    @deflate.Ok(_) => fail("Should have failed on empty data")
    @deflate.Err(error) =>
      // Snapshot: Should mention size - test the error message
      inspect(error, content="File too small to be a valid ZIP archive")
  }
}

///|
test "compression levels api" {
  let test_data = "Test data for levels"

  // Verify test data is not empty
  inspect(test_data.length() > 0, content="true")

  // Test that all level constructors work
  let none_level = @deflate.level_none()
  let fast_level = @deflate.level_fast()
  let default_level = @deflate.level_default()
  let best_level = @deflate.level_best()

  // Test compression with different levels
  match @zipc.deflate_of_binary_string(test_data, none_level) {
    @deflate.Ok(compressed) =>
      // Snapshot: Should produce compressed file
      inspect(compressed.compressed_size() > 0, content="true")
    @deflate.Err(error) => fail("Level None compression failed: " + error)
  }
  match @zipc.deflate_of_binary_string(test_data, fast_level) {
    @deflate.Ok(compressed) =>
      // Snapshot: Should produce compressed file
      inspect(compressed.compressed_size() > 0, content="true")
    @deflate.Err(error) => fail("Level Fast compression failed: " + error)
  }

  // Test default and best levels as well
  match @zipc.deflate_of_binary_string(test_data, default_level) {
    @deflate.Ok(compressed) =>
      // Snapshot: Should produce compressed file
      inspect(compressed.compressed_size() > 0, content="true")
    @deflate.Err(error) => fail("Level Default compression failed: " + error)
  }
  match @zipc.deflate_of_binary_string(test_data, best_level) {
    @deflate.Ok(compressed) =>
      // Snapshot: Should produce compressed file
      inspect(compressed.compressed_size() > 0, content="true")
    @deflate.Err(error) => fail("Level Best compression failed: " + error)
  }
}
