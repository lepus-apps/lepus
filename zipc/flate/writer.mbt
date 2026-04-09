///|
struct Writer {
  d : Compressor
  // dict : Slice[Byte]
}

///|
/// `Writer::new` returns a new [@io.WriteCloser] compressing data at the "BestSpeed" level.
/// It writes its (compressed) data to the provided `buf`.
pub fn Writer::new(buf : &@io.Writer) -> Writer {
  let d = Compressor::new(buf)
  // let dict = Bytes::new(0)
  // { d, dict }
  { d, }
}

// `Writer::new_dict` is like [NewWriter] but initializes the new
// [Writer] with a preset dictionary. The returned [Writer] behaves
// as if the dictionary had been written to it without producing
// any compressed output. The compressed data written to w
// can only be decompressed by a [Reader] initialized with the
// same dictionary.

///|
pub fn Writer::new_dict(w : &@io.Writer, dict : Slice[Byte]) -> Writer {
  let dw = { w, }
  let zw = Writer::new(dw)
  zw.d.fill_window(dict)
  // zw.dict.append(dict) // duplicate dictionary for Reset method.
  zw
}

///|
struct DictWriter {
  w : &@io.Writer
}

///|
pub impl @io.Writer for DictWriter with write(self, b) {
  self.w.write(b)
}

///|
/// `write` writes the provided data to the flate Writer.
pub impl @io.Writer for Writer with write(self, data) {
  self.d.write(data)
}

///|
/// `close` closes the input to the flate Writer.
/// After closing the Writer, the compressed data can be read
/// from the `@io.Writer` provided to `new`.
pub impl @io.Closer for Writer with close(self) {
  self.d.close()
}

///|
pub impl @io.WriteCloser for Writer
