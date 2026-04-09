// This file is based on the Go implementation found here:
// https://cs.opensource.google/go/go/+/refs/tags/go1.23.1:src/compress/flate/dict_decoder_test.go
// which has the copyright notice:
// Copyright 2016 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

///|
test "DictDecoder" {
  let abc = "ABC\n"
  let fox = "The quick brown fox jumped over the lazy dog!\n"
  let poem =
    #|The Road Not Taken
    #|Robert Frost
    #|
    #|Two roads diverged in a yellow wood,
    #|And sorry I could not travel both
    #|And be one traveler, long I stood
    #|And looked down one as far as I could
    #|To where it bent in the undergrowth;
    #|
    #|Then took the other, as just as fair,
    #|And having perhaps the better claim,
    #|Because it was grassy and wanted wear;
    #|Though as for that the passing there
    #|Had worn them really about the same,
    #|
    #|And both that morning equally lay
    #|In leaves no step had trodden black.
    #|Oh, I kept the first for another day!
    #|Yet knowing how way leads on to way,
    #|I doubted if I should ever come back.
    #|
    #|I shall be telling this with a sigh
    #|Somewhere ages and ages hence:
    #|Two roads diverged in a wood, and I-
    #|I took the one less traveled by,
    #|And that has made all the difference.
    #|

  // dist   int // Backward distance (0 if this is an insertion)
  // length int // Length of copy or insertion
  let poem_refs = [
    (0, 38),
    (33, 3),
    (0, 48),
    (79, 3),
    (0, 11),
    (34, 5),
    (0, 6),
    (23, 7),
    (0, 8),
    (50, 3),
    (0, 2),
    (69, 3),
    (34, 5),
    (0, 4),
    (97, 3),
    (0, 4),
    (43, 5),
    (0, 6),
    (7, 4),
    (88, 7),
    (0, 12),
    (80, 3),
    (0, 2),
    (141, 4),
    (0, 1),
    (196, 3),
    (0, 3),
    (157, 3),
    (0, 6),
    (181, 3),
    (0, 2),
    (23, 3),
    (77, 3),
    (28, 5),
    (128, 3),
    (110, 4),
    (70, 3),
    (0, 4),
    (85, 6),
    (0, 2),
    (182, 6),
    (0, 4),
    (133, 3),
    (0, 7),
    (47, 5),
    (0, 20),
    (112, 5),
    (0, 1),
    (58, 3),
    (0, 8),
    (59, 3),
    (0, 4),
    (173, 3),
    (0, 5),
    (114, 3),
    (0, 4),
    (92, 5),
    (0, 2),
    (71, 3),
    (0, 2),
    (76, 5),
    (0, 1),
    (46, 3),
    (96, 4),
    (130, 4),
    (0, 3),
    (360, 3),
    (0, 3),
    (178, 5),
    (0, 7),
    (75, 3),
    (0, 3),
    (45, 6),
    (0, 6),
    (299, 6),
    (180, 3),
    (70, 6),
    (0, 1),
    (48, 3),
    (66, 4),
    (0, 3),
    (47, 5),
    (0, 9),
    (325, 3),
    (0, 1),
    (359, 3),
    (318, 3),
    (0, 2),
    (199, 3),
    (0, 1),
    (344, 3),
    (0, 3),
    (248, 3),
    (0, 10),
    (310, 3),
    (0, 3),
    (93, 6),
    (0, 3),
    (252, 3),
    (157, 4),
    (0, 2),
    (273, 5),
    (0, 14),
    (99, 4),
    (0, 1),
    (464, 4),
    (0, 2),
    (92, 4),
    (495, 3),
    (0, 1),
    (322, 4),
    (16, 4),
    (0, 3),
    (402, 3),
    (0, 2),
    (237, 4),
    (0, 2),
    (432, 4),
    (0, 1),
    (483, 5),
    (0, 2),
    (294, 4),
    (0, 2),
    (306, 3),
    (113, 5),
    (0, 1),
    (26, 4),
    (164, 3),
    (488, 4),
    (0, 1),
    (542, 3),
    (248, 6),
    (0, 5),
    (205, 3),
    (0, 8),
    (48, 3),
    (449, 6),
    (0, 2),
    (192, 3),
    (328, 4),
    (9, 5),
    (433, 3),
    (0, 3),
    (622, 25),
    (615, 5),
    (46, 5),
    (0, 2),
    (104, 3),
    (475, 10),
    (549, 3),
    (0, 4),
    (597, 8),
    (314, 3),
    (0, 1),
    (473, 6),
    (317, 5),
    (0, 1),
    (400, 3),
    (0, 3),
    (109, 3),
    (151, 3),
    (48, 4),
    (0, 4),
    (125, 3),
    (108, 3),
    (0, 2),
  ]
  let got = @buffer.new()
  let want = @buffer.new()
  let dd = DictDecoder::new(1 << 11, Slice::new([]))
  let write_copy = fn(dist, length) {
    let mut length = length
    while length > 0 {
      let mut cnt = dd.try_write_copy(dist, length)
      if cnt == 0 {
        cnt = dd.write_copy(dist, length)
      }
      length -= cnt
      if dd.avail_write() == 0 {
        got.write_bytes(Bytes::from_iter(dd.read_flush().iter()))
      }
    }
  }
  let write_string = fn(str : String) {
    let mut str = Slice::new(str2bytes(str).to_array())
    while str.length() > 0 {
      let cnt = slice_copy(dd.write_slice(), str)
      str = str[cnt:]
      dd.write_mark(cnt)
      if dd.avail_write() == 0 {
        got.write_bytes(Bytes::from_iter(dd.read_flush().iter()))
      }
    }
  }

  //
  write_string(".")
  want.write_char('.')

  //
  let mut str = poem
  for pref in poem_refs {
    if pref.0 == 0 {
      write_string(str[:pref.1].to_string())
    } else {
      write_copy(pref.0, pref.1)
    }
    str = str[pref.1:].to_string()
  }

  //
  want.write_string(poem)
  write_copy(dd.hist_size(), 33)
  want.write_view(want.contents().to_unchecked_string()[0:33])

  //
  write_string(abc)
  write_copy(abc.length(), 59 * abc.length())
  want.write_string(abc.repeat(60))

  //
  write_string(fox)
  write_copy(fox.length(), 9 * fox.length())
  want.write_string(fox.repeat(10))

  //
  write_string(".")
  write_copy(1, 9)
  want.write_string(".".repeat(10))

  //
  write_string(poem.to_upper())
  write_copy(poem.length(), 7 * poem.length())
  want.write_string(poem.to_upper().repeat(8))

  //
  write_copy(dd.hist_size(), 10)
  let to_drop = want.contents().to_unchecked_string().length() - dd.hist_size()
  want.write_view(want.contents().to_unchecked_string()[to_drop:to_drop + 10])

  //
  got.write_bytes(Bytes::from_iter(dd.read_flush().iter()))
  let got = bytes2str(got.to_bytes())
  let want = want.contents().to_unchecked_string()
  if got != want {
    abort("final string mismatch:\ngot  \{got}\nwant \{want}")
  }
}

///|
/// `bytes2str` decodes a UTF-8 `Bytes` to a UTF-16 `String`.
fn bytes2str(b : Bytes) -> String {
  let chars = (b.iter() |> @decoder.utf8()).collect()
  let buf = @buffer.new(size_hint=chars.length())
  for ch in chars {
    buf.write_char(ch)
  }
  buf.contents().to_unchecked_string()
}

///|
test "bytes2str works on simple case" {
  let got = bytes2str(b"simple case")
  assert_eq(got, "simple case")
}

///|
/// `str2bytes` encodes a UTF-16 `String` as a UTF-8 `Bytes`.
fn str2bytes(s : String) -> Bytes {
  s.iter() |> @encoder.utf8() |> Bytes::from_iter()
}

///|
test "str2bytes works on simple case" {
  let got = str2bytes("simple case")
  assert_eq(got, b"simple case")
}
