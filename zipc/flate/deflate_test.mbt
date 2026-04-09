// This file is based on the Go implementation found here:
// https://cs.opensource.google/go/go/+/refs/tags/go1.23.1:src/compress/flate/deflate_test.go
// which has the copyright notice:
// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

///|
using @io {type Slice}

///|
suberror TestError {
  TestError(String)
} derive(Debug)

///|
test "writer dict" {
  let dict = Slice::new(b"hello world".to_array())
  let text = Slice::new(b"hello again world".to_array())
  let b = @io.Buffer::new()
  let w = @flate.Writer::new(b)
  guard w.write(dict) is (11, None)
  // w.flush()
  // b.reset()
  guard w.write(text) is (17, None)
  guard w.close() is None
  let want = b.to_bytes().to_array()
  assert_eq(38, want.length())

  //
  let b1 = @io.Buffer::new()
  let w = @flate.Writer::new_dict(b1, dict)
  guard w.write(text) is (17, None)
  guard w.close() is None

  //
  let got = b1.to_bytes().to_array()
  assert_eq(38, got.length())
  if got != want {
    raise TestError("writer wrote \{got} want \{want}")
  }
}
