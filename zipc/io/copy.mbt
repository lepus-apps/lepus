///|
/// copy_until copies bytes from a source reader to a destination writer
/// until a specified byte is encountered. It returns the number of bytes
/// copied and any error that occurred during the process.
pub fn copy_until(
  dst : &Writer,
  src : &ByteReader,
  until : Byte,
) -> (Int64, IOError?) {
  let mut total = 0L
  for ;; {
    let (b, err) = src.read_byte()
    guard err is None else { return (total, err) }
    let (_, err) = dst.write(Slice::new([b]))
    total += 1
    guard err is None else { return (total, err) }
    if b == until {
      return (total, None)
    }
  }
}

///|
/// copy_size copies a specified number of bytes from a source reader to a
/// destination writer. It returns the number of bytes copied and any error
/// that occurred during the process.
pub fn copy_size(
  dst : &Writer,
  src : &ByteReader,
  size : Int64,
) -> (Int64, IOError?) {
  let mut total = 0L
  for ;; {
    let (b, err) = src.read_byte()
    guard err is None else { return (total, err) }
    let (_, err) = dst.write(Slice::new([b]))
    total += 1
    guard err is None else { return (total, err) }
    if total == size {
      return (total, None)
    }
  }
}
