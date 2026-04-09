///|
struct MultiReader {
  mut count : Int
}

///|
impl @io.Reader for MultiReader with read(self, buf) {
  if self.count >= 2 {
    return (0, Some(@io.eof))
  }
  // Return exactly the buffer length to trigger resize in read_all if possible
  let n = buf.length()
  for i in 0..<n {
    buf[i] = b'a'
  }
  self.count += 1
  (n, None)
}

///|
test "read_all resize bug" {
  let r : MultiReader = MultiReader::{ count: 0 }
  // read_all initial cap is 512.
  // First read will fill 512 bytes.
  // Then it will resize to 1024.
  // Second read will try to read into b[512:1024].
  let (res, err) = @io.read_all(r)
  if err != None {
    abort("Should not have error")
  }
  inspect(res.length(), content="1024")
}
