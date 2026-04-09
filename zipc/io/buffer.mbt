///|
struct Buffer {
  mut b : Slice[Byte]
  // off represent the current read/write position in the buffer.
  // It is recommended to use the buffer as a reader or writer
  // but not both at the same time.
  mut off : Int
}

///|
/// Buffer::new creates a new empty Buffer with an optional size hint.
/// The size hint is used to preallocate memory for the buffer, which can
/// improve performance when the size of the data to be written is known in advance.
pub fn Buffer::new(size_hint? : Int = 0) -> Buffer {
  let b = Slice::new(Array::make(size_hint, b'\x00'), start=0, end=0)
  { b, off: 0 }
}

///|
let _trait4 : &Reader = Buffer::new()

///|
let _trait5 : &Writer = Buffer::new()

///|
pub fn Buffer::from_slice(s : Slice[Byte]) -> Buffer {
  let b = Slice::new(s.to_bytes().to_array())
  { b, off: 0 }
}

///|
pub fn Buffer::from_bytes(b : Bytes) -> Buffer {
  let buf = Slice::new(b.to_array())
  { b: buf, off: 0 }
}

///|
/// `Buffer::from_string` converts the MoonBit UTF-16 String to UTF-8
/// and creates a Buffer from the bytes.
pub fn Buffer::from_string(s : String) -> Buffer {
  let b = @utf8.encode(s)
  let buf = Slice::new(b.to_array())
  { b: buf, off: 0 }
}

///|
pub fn Buffer::reset(self : Buffer, size_hint? : Int = 0) -> Unit {
  self.b = Slice::new(Array::make(size_hint, b'\x00'), start=0, end=0)
  self.off = 0
}

///|
pub impl Writer for Buffer with write(self, buf) {
  let blen = self.b.length()
  let buflen = buf.length()
  self.b = Slice::new(
    Array::makei(blen + buflen, fn(i) {
      if i < blen {
        self.b[i]
      } else {
        buf.buf[buf.start + i - blen]
      }
    }),
  )
  (buflen, None)
}

///|
pub fn Buffer::write_bytes(self : Buffer, buf : Bytes) -> (Int, IOError?) {
  self.write(Slice::new(buf.to_array()))
}

///|
pub fn Buffer::write_byte(self : Buffer, b : Byte) -> (Int, IOError?) {
  self.write(Slice::new([b]))
}

///|
/// `write_string` converts the MoonBit UTF-16 String to UTF-8 and
/// writes the bytes to the buffer.
pub fn Buffer::write_string(self : Buffer, s : String) -> (Int, IOError?) {
  let b = @utf8.encode(s)
  self.write_bytes(b)
}

///|
pub impl Reader for Buffer with read(self, buf) {
  let remaining = self.b.length() - self.off
  if remaining <= 0 || buf.length() == 0 {
    return (0, Some(eof))
  }
  let n = minimum(remaining, buf.length())
  Array::unsafe_blit(buf.buf, buf.start, self.b.buf, self.off, n)
  self.off += n
  (n, None)
}

///|
pub impl ByteReader for Buffer with read_byte(self) {
  let remaining = self.b.length() - self.off
  if remaining <= 0 {
    return (0, Some(eof))
  }
  let b = self.b[self.off]
  self.off += 1
  (b, None)
}

///|
pub fn Buffer::read_from(self : Buffer, r : &Reader) -> (Int64, IOError?) {
  copy(self, r)
}

///|
fn minimum(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
pub fn Buffer::to_bytes(self : Buffer) -> Bytes {
  Bytes::from_array(self.b.buf)
}

///|
pub impl Show for Buffer with to_string(self) {
  @utf8.decode_lossy(Bytes::from_array(self.b.buf)[:])
}

///|
pub impl Show for Buffer with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
pub impl Eq for Buffer with equal(self, other) {
  if self.b.length() != other.b.length() {
    return false
  }
  for i in 0..<self.b.length() {
    if self.b[i] != other.b[i] {
      return false
    }
  }
  true
}

///|
pub fn Buffer::to_slice(self : Buffer) -> Slice[Byte] {
  Slice::new(self.b.buf)
}

///|
pub fn Buffer::length(self : Buffer) -> Int {
  self.b.length()
}

///|
pub fn Buffer::op_get(self : Buffer, index : Int) -> Byte {
  self.b[index]
}

///|
pub fn Buffer::substring(self : Buffer, start? : Int = 0, end? : Int) -> String {
  let end = match end {
    None => self.b.length()
    Some(x) => x
  }
  guard start >= 0 && start <= end && end <= self.b.length() else {
    abort(
      "Buffer::substring(start=\{start}, end=\{end}) out of bounds for length=\{self.b.length()})",
    )
  }
  let bytes = Bytes::from_iter(self.b[start:end].iter())
  @utf8.decode_lossy(bytes[:])
}

///|
test "Buffer::substring" {
  let buf = Buffer::new()
  buf.write_string("hello world") |> ignore()
  inspect(buf.substring(), content="hello world")
  inspect(buf.substring(start=6), content="world")
  inspect(buf.substring(start=0, end=5), content="hello")
}

///|
test "panic Buffer::substring/out-of-bounds 1" {
  let buf = Buffer::from_string("hello world")
  ignore(buf.substring(start=-1))
}

///|
test "panic Buffer::substring/out-of-bounds 2" {
  let buf = Buffer::from_string("hello world")
  ignore(buf.substring(start=12))
}

///|
test "panic Buffer::substring/out-of-bounds 3" {
  let buf = Buffer::from_string("hello world")
  ignore(buf.substring(start=0, end=12))
}

///|
test "panic Buffer::substring/out-of-bounds 4" {
  let buf = Buffer::from_string("hello world")
  ignore(buf.substring(start=6, end=5))
}

///|
test "Buffer::substring/empty" {
  let buf = Buffer::new()
  inspect(buf.substring(), content="")
  inspect(buf.substring(start=0, end=0), content="")
}
