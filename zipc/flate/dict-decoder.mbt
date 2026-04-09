// This file is based on the Go implementation found here:
// https://cs.opensource.google/go/go/+/refs/tags/go1.23.1:src/compress/flate/dict_decoder.go
// which has the copyright notice:
// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

///|
/// DictDecoder implements the LZ77 sliding dictionary as used in decompression.
/// LZ77 decompresses data through sequences of two forms of commands:
///
///   - Literal insertions: Runs of one or more symbols are inserted into the data
///     stream as is. This is accomplished through the write_byte method for a
///     single symbol, or combinations of write_slice/write_mark for multiple symbols.
///     Any valid stream must start with a literal insertion if no preset dictionary
///     is used.
///
///   - Backward copies: Runs of one or more symbols are copied from previously
///     emitted data. Backward copies come as the tuple (dist, length) where dist
///     determines how far back in the stream to copy from and length determines how
///     many bytes to copy. Note that it is valid for the length to be greater than
///     the distance. Since LZ77 uses forward copies, that situation is used to
///     perform a form of run-length encoding on repeated runs of symbols.
///     The write_copy and try_write_copy are used to implement this command.
///
/// For performance reasons, this implementation performs little to no sanity
/// checks about the arguments. As such, the invariants documented for each
/// method call must be respected.
priv struct DictDecoder {
  hist : Slice[Byte] // []byte // Sliding window history

  // Invariant: 0 <= rd_pos <= wr_pos <= len(hist)
  mut wr_pos : Int // Current output position in buffer
  mut rd_pos : Int // Have emitted hist[:rd_pos] already
  mut full : Bool // Has a full window length been written yet?
}

///|
/// DictDecoder::new initializes DictDecoder to have a sliding window dictionary of the given
/// size. If a preset dict is provided, it will initialize the dictionary with
/// the contents of dict.
fn DictDecoder::new(size : Int, dict : Slice[Byte]) -> DictDecoder {
  let dd = {
    hist: Slice::new(Array::make(size, b'\x00')),
    wr_pos: 0,
    rd_pos: 0,
    full: false,
  }
  let mut dict = dict
  if dict.length() > size {
    dict = dict[dict.length() - size:]
  }
  dd.wr_pos = slice_copy(dd.hist, dict)
  if dd.wr_pos == size {
    dd.wr_pos = 0
    dd.full = true
  }
  dd.rd_pos = dd.wr_pos
  dd
}

///|
/// hist_size reports the total amount of historical data in the dictionary.
fn DictDecoder::hist_size(self : DictDecoder) -> Int {
  if self.full {
    return self.hist.length()
  }
  self.wr_pos
}

///|
/// avail_read reports the number of bytes that can be flushed by read_flush.
fn DictDecoder::avail_read(self : DictDecoder) -> Int {
  self.wr_pos - self.rd_pos
}

///|
/// avail_write reports the available amount of output buffer space.
fn DictDecoder::avail_write(self : DictDecoder) -> Int {
  self.hist.length() - self.wr_pos
}

///|
/// write_slice returns a slice of the available buffer to write data to.
///
/// This invariant will be kept: len(s) <= avail_write()
fn DictDecoder::write_slice(self : DictDecoder) -> Slice[Byte] {
  self.hist[self.wr_pos:]
}

///|
/// write_mark advances the writer pointer by cnt.
///
/// This invariant must be kept: 0 <= cnt <= avail_write()
fn DictDecoder::write_mark(self : DictDecoder, cnt : Int) -> Unit {
  self.wr_pos += cnt
}

///|
/// write_byte writes a single byte to the dictionary.
///
/// This invariant must be kept: 0 < avail_write()
fn DictDecoder::write_byte(self : DictDecoder, c : Byte) -> Unit {
  self.hist[self.wr_pos] = c
  self.wr_pos += 1
}

///|
/// write_copy copies a string at a given (dist, length) to the output.
/// This returns the number of bytes copied and may be less than the requested
/// length if the available space in the output buffer is too small.
///
/// This invariant must be kept: 0 < dist <= hist_size()
fn DictDecoder::write_copy(self : DictDecoder, dist : Int, length : Int) -> Int {
  let dst_base = self.wr_pos
  let mut dst_pos = dst_base
  let mut src_pos = dst_pos - dist
  let mut end_pos = dst_pos + length
  if end_pos > self.hist.length() {
    end_pos = self.hist.length()
  }

  // Copy non-overlapping section after destination position.
  //
  // This section is non-overlapping in that the copy length for this section
  // is always less than or equal to the backwards distance. This can occur
  // if a distance refers to data that wraps-around in the buffer.
  // Thus, a backwards copy is performed here; that is, the exact bytes in
  // the source prior to the copy is placed in the destination.
  if src_pos < 0 {
    src_pos += self.hist.length()
    dst_pos += slice_copy(self.hist[dst_pos:end_pos], self.hist[src_pos:])
    src_pos = 0
  }

  // Copy possibly overlapping section before destination position.
  //
  // This section can overlap if the copy length for this section is larger
  // than the backwards distance. This is allowed by LZ77 so that repeated
  // strings can be succinctly represented using (dist, length) pairs.
  // Thus, a forwards copy is performed here; that is, the bytes copied is
  // possibly dependent on the resulting bytes in the destination as the copy
  // progresses along.
  while dst_pos < end_pos {
    dst_pos += slice_copy(
      self.hist[dst_pos:end_pos],
      self.hist[src_pos:dst_pos],
    )
  }

  //
  self.wr_pos = dst_pos
  return dst_pos - dst_base
}

///|
/// try_write_copy tries to copy a string at a given (distance, length) to the
/// output. This specialized version is optimized for short distances.
///
/// This method is designed to be inlined for performance reasons.
///
/// This invariant must be kept: 0 < dist <= hist_size()
fn DictDecoder::try_write_copy(
  self : DictDecoder,
  dist : Int,
  length : Int,
) -> Int {
  let mut dst_pos = self.wr_pos
  let end_pos = dst_pos + length
  if dst_pos < dist || end_pos > self.hist.length() {
    return 0
  }
  let dst_base = dst_pos
  let src_pos = dst_pos - dist

  // Copy possibly overlapping section before destination position.
  while dst_pos < end_pos {
    dst_pos += slice_copy(
      self.hist[dst_pos:end_pos],
      self.hist[src_pos:dst_pos],
    )
  }
  self.wr_pos = dst_pos
  return dst_pos - dst_base
}

///|
fn slice_copy(dst : Slice[Byte], src : Slice[Byte]) -> Int {
  let n = @cmp.minimum(dst.length(), src.length())
  for i = 0; i < n; i = i + 1 {
    dst[i] = src[i]
  }
  n
}

///|
/// read_flush returns a slice of the historical buffer that is ready to be
/// emitted to the user. The data returned by read_flush must be fully consumed
/// before calling any other DictDecoder methods.
fn DictDecoder::read_flush(self : DictDecoder) -> Slice[Byte] {
  let to_read = self.hist[self.rd_pos:self.wr_pos]
  self.rd_pos = self.wr_pos
  if self.wr_pos == self.hist.length() {
    self.wr_pos = 0
    self.rd_pos = 0
    self.full = true
  }
  return to_read
}
