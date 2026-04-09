// This file is based on the Go implementation found here:
// https://cs.opensource.google/go/go/+/refs/tags/go1.23.1:src/compress/flate/deflate_test.go
// which has the copyright notice:
// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TestBestSpeed tests that round-tripping through deflate and then inflate
// recovers the original input. The Write sizes are near the thresholds in the
// compressor.encSpeed method (0, 16, 128), as well as near maxStoreBlockSize
// (65535).

///|
test "TestBestSpeed" {
  let abc_len = 128
  let abc = FixedArray::make(abc_len, b'\x00')
  for i = 0; i < abc_len; i = i + 1 {
    abc[i] = i.to_byte()
  }
  let num_copies = 131072 / abc_len
  let abcabc = FixedArray::make(abc_len * num_copies, b'\x00')
  for i = 0; i < num_copies; i = i + 1 {
    FixedArray::unsafe_blit(abcabc, i * abc_len, abc, 0, abc_len)
  }

  //
  let test_cases = [
    [65536, 0],
    [65536, 1],
    [65536, 1, 256],
    [65536, 1, 65536],
    [65536, 14],
    [65536, 15],
    [65536, 16],
    [65536, 16, 256],
    [65536, 16, 65536],
    [65536, 127],
    [65536, 128],
    [65536, 128, 256],
    [65536, 128, 65536],
    [65536, 129],
    [65536, 65536, 256],
    [65536, 65536, 65536],
  ]

  //
  let mut i = 0
  for tc in test_cases {
    for first_n in [1, 65534, 65535, 65536, 65537, 131072] {
      i += 1
      tc[0] = first_n
      let buf = @io.Buffer::new()
      let want = @io.Buffer::new()
      let w : &@io.WriteCloser = @flate.Writer::new(buf)
      for n in tc {
        // TODO: Changing from Bytes to FixedArray[Byte] hurts performance.
        let subset = FixedArray::make(n, b'\x00')
        subset.unsafe_blit(0, abcabc, 0, n)
        let subset = Bytes::from_array(subset)
        let (_, err) = want.write_bytes(subset)
        guard err is None else {
          abort(
            "test #\{i}: want.write_bytes(subset): unexpected error: \{err}",
          )
        }
        let (_, err) = w.write(@io.Slice::new(subset.to_array()))
        guard err is None else {
          abort("test #\{i}: w.write(): unexpected error: \{err}")
        }
        // if !(flush) {
        // continue
        // }
        // w.flush!()
      }
      let want = want.to_bytes()
      let err = w.close()
      guard err is None else {
        abort("test #\{i}: w.close(): unexpected error: \{err}")
      }

      //
      let got = @io.Buffer::new()
      let r : &@io.ReadCloser = &@flate.Reader::new(buf)
      let (_, err) = @io.copy(got, r)
      guard err is None else { abort("test #\{i}: @io.copy: \{err}") }
      try {
        let got = got.to_bytes()
        assert_eq(got, want)
      } catch {
        _ => abort("test #\{i} FAILED")
      }
    }
  }
}
