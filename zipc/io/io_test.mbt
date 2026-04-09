// This file is based on the Go implementation found here:
// https://cs.opensource.google/go/go/+/refs/tags/go1.23.2:src/io/io_test.go
// which has the copyright notice:
// copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Simple tests, primarily to verify the ReadFrom and WriteTo callouts inside Copy, CopyBuffer and CopyN.

///|
test "TestCopy" {
  let rb = @io.Buffer::new()
  let wb = @io.Buffer::new()
  guard rb.write_bytes(b"hello, world.") is (13, None)
  guard @io.copy(wb, rb) is (13, None)
  assert_eq(wb.to_bytes(), b"hello, world.")

  // reuse buffers
  rb.reset()
  wb.reset()
  guard rb.write_bytes(b"hello, world.") is (13, None)
  guard rb.write_bytes(b"hello, world.") is (13, None)
  guard @io.copy(wb, rb) is (26, None)
  assert_eq(wb.to_bytes(), b"hello, world.hello, world.")
}

// test "TestCopyNegative" {
// 	let rb = @io.Buffer::new()
// 	let wb = @io.Buffer::new()
// 	let _ = rb.write_bytes(b"hello")
// 	let _ = @io.copy(wb, &LimitedReader{R: rb, N: -1})
// 	if wb.to_bytes() != b"" {
// 		t.Errorf("Copy on LimitedReader with N<0 copied data")
// 	}

// 	let _ = @io.copy_n(wb, rb, -1)
// 	if wb.to_bytes() != b"" {
// 		t.Errorf("CopyN with N<0 copied data")
// 	}
// }

///|
test "TestCopyBuffer" {
  let rb = @io.Buffer::new()
  let wb = @io.Buffer::new()
  guard rb.write_bytes(b"hello, world.") is (13, None)
  guard @io.copy_buffer(wb, rb, Some(@io.Slice::new([0]))) is (13, None)  // Tiny buffer to keep it honest.
  assert_eq(wb.to_bytes(), b"hello, world.")
}

///|
test "TestCopyBufferNone" {
  let rb = @io.Buffer::new()
  let wb = @io.Buffer::new()
  guard rb.write_bytes(b"hello, world.") is (13, None)
  guard @io.copy_buffer(wb, rb, None) is (13, None)  // Should allocate a buffer.
  assert_eq(wb.to_bytes(), b"hello, world.")
}

// test "TestCopyReadFrom" {
// 	let rb = @io.Buffer::new()
// 	let wb = new(bytes.Buffer) // implements ReadFrom.
// 	let _ = rb.write_bytes(b"hello, world.")
// 	let _ = @io.copy(wb, rb)
// 	if wb.to_bytes() != b"hello, world." {
// 		t.Errorf("Copy did not work properly")
// 	}
// }

// test "TestCopyWriteTo" {
// 	let rb = new(bytes.Buffer) // implements WriteTo.
// 	let wb = @io.Buffer::new()
// 	let _ = rb.write_bytes(b"hello, world.")
// 	let _ = @io.copy(wb, rb)
// 	if wb.to_bytes() != b"hello, world." {
// 		t.Errorf("Copy did not work properly")
// 	}
// }

// // Version of bytes.Buffer that checks whether WriteTo was called or not
// type writeToChecker struct {
// 	bytes.Buffer
// 	writeToCalled bool
// }

// func (wt *writeToChecker) WriteTo(w Writer) (int64, error) {
// 	wt.writeToCalled = true
// 	return wt.Buffer.WriteTo(w)
// }

// // It's preferable to choose WriterTo over ReaderFrom, since a WriterTo can issue one large write,
// // while the ReaderFrom must read until EOF, potentially allocating when running out of buffer.
// // Make sure that we choose WriterTo when both are implemented.
// test "TestCopyPriority" {
// 	let rb = new(writeToChecker)
// 	let wb = new(bytes.Buffer)
// 	let _ = rb.write_bytes(b"hello, world.")
// 	let _ = @io.copy(wb, rb)
// 	if wb.to_bytes() != b"hello, world." {
// 		t.Errorf("Copy did not work properly")
// 	} else if !rb.writeToCalled {
// 		t.Errorf("WriteTo was not prioritized over ReadFrom")
// 	}
// }

// type zeroErrReader struct {
// 	err error
// }

// func (r zeroErrReader) Read(p []byte) (int, error) {
// 	return @io.copy(p, []byte{0}), r.err
// }

// type errWriter struct {
// 	err error
// }

// func (w errWriter) Write([]byte) (int, error) {
// 	return 0, w.err
// }

// // In case a Read results in an error with non-zero bytes read, and
// // the subsequent Write also results in an error, the error from Write
// // is returned, as it is the one that prevented progressing further.
// test "TestCopyReadErrWriteErr" {
// 	let er, ew = errors.New("readError"), errors.New("writeError")
// 	let r, w = zeroErrReader{err: er}, errWriter{err: ew}
// 	let n, err = @io.copy(w, r)
// 	if n != 0 || err != ew {
// 		t.Errorf("@io.copy(zeroErrReader, errWriter) = %d, %v; want 0, writeError", n, err)
// 	}
// }

///|
test "TestCopyN" {
  let rb = @io.Buffer::new()
  let wb = @io.Buffer::new()
  guard rb.write_bytes(b"hello, world.") is (13, None)
  guard @io.copy_n(wb, rb, 5) is (5, None)
  assert_eq(wb.to_bytes(), b"hello")
}

// test "TestCopyNReadFrom" {
// 	let rb = @io.Buffer::new()
// 	let wb = new(bytes.Buffer) // implements ReadFrom.
// 	let _ = rb.write_bytes(b"hello")
// 	let _ = @io.copy_n(wb, rb, 5)
// 	if wb.to_bytes() != b"hello" {
// 		t.Errorf("CopyN did not work properly")
// 	}
// }

// test "TestCopyNWriteTo" {
// 	let rb = new(bytes.Buffer) // implements WriteTo.
// 	let wb = @io.Buffer::new()
// 	let _ = rb.write_bytes(b"hello, world.")
// 	let _ = @io.copy_n(wb, rb, 5)
// 	if wb.to_bytes() != b"hello" {
// 		t.Errorf("CopyN did not work properly")
// 	}
// }

// func BenchmarkCopyNSmall(b *testing.B) {
// 	let bs = bytes.Repeat([]byte{0}, 512+1)
// 	let rd = bytes.NewReader(bs)
// 	let buf = @io.Buffer::new()
// 	b.ResetTimer()

// 	let for i = 0; i < b.N; i++ {
// 		let _ = @io.copy_n(buf, rd, 512)
// 		rd.Reset(bs)
// 	}
// }

// func BenchmarkCopyNLarge(b *testing.B) {
// 	let bs = bytes.Repeat([]byte{0}, (32*1024)+1)
// 	let rd = bytes.NewReader(bs)
// 	let buf = @io.Buffer::new()
// 	b.ResetTimer()

// 	let for i = 0; i < b.N; i++ {
// 		let _ = @io.copy_n(buf, rd, 32*1024)
// 		rd.Reset(bs)
// 	}
// }

// type noReadFrom struct {
// 	w Writer
// }

// func (w *noReadFrom) Write(p []byte) (n int, err error) {
// 	return w.w.Write(p)
// }

// type wantedAndErrReader struct{}

// func (wantedAndErrReader) Read(p []byte) (int, error) {
// 	return len(p), errors.New("wantedAndErrReader error")
// }

// test "TestCopyNEOF" {
// 	// Test that EOF behavior is the same regardless of whether
// 	// argument to CopyN has ReadFrom.

// 	let b = new(bytes.Buffer)

// 	let n, err = CopyN(&noReadFrom{b}, strings.NewReader("foo"), 3)
// 	if n != 3 || err != None {
// 		t.Errorf("CopyN(noReadFrom, foo, 3) = %d, %v; want 3, None", n, err)
// 	}

// 	n, err = CopyN(&noReadFrom{b}, strings.NewReader("foo"), 4)
// 	if n != 3 || err != EOF {
// 		t.Errorf("CopyN(noReadFrom, foo, 4) = %d, %v; want 3, EOF", n, err)
// 	}

// 	n, err = CopyN(b, strings.NewReader("foo"), 3) // b has read from
// 	if n != 3 || err != None {
// 		t.Errorf("CopyN(bytes.Buffer, foo, 3) = %d, %v; want 3, None", n, err)
// 	}

// 	n, err = CopyN(b, strings.NewReader("foo"), 4) // b has read from
// 	if n != 3 || err != EOF {
// 		t.Errorf("CopyN(bytes.Buffer, foo, 4) = %d, %v; want 3, EOF", n, err)
// 	}

// 	n, err = CopyN(b, wantedAndErrReader{}, 5)
// 	if n != 5 || err != None {
// 		t.Errorf("CopyN(bytes.Buffer, wantedAndErrReader, 5) = %d, %v; want 5, None", n, err)
// 	}

// 	n, err = CopyN(&noReadFrom{b}, wantedAndErrReader{}, 5)
// 	if n != 5 || err != None {
// 		t.Errorf("CopyN(noReadFrom, wantedAndErrReader, 5) = %d, %v; want 5, None", n, err)
// 	}
// }

// test "TestReadAtLeast" {
// 	var rb bytes.Buffer
// 	testReadAtLeast(t, &rb)
// }

// // A version of bytes.Buffer that returns n > 0, err on Read
// // when the input is exhausted.
// type dataAndErrorBuffer struct {
// 	err error
// 	bytes.Buffer
// }

// func (r *dataAndErrorBuffer) Read(p []byte) (n int, err error) {
// 	n, err = r.Buffer.Read(p)
// 	if n > 0 && r.Buffer.Len() == 0 && err == None {
// 		err = r.err
// 	}
// 	return
// }

// test "TestReadAtLeastWithDataAndEOF" {
// 	var rb dataAndErrorBuffer
// 	rb.err = EOF
// 	testReadAtLeast(t, &rb)
// }

// test "TestReadAtLeastWithDataAndError" {
// 	var rb dataAndErrorBuffer
// 	rb.err = fmt.Errorf("fake error")
// 	testReadAtLeast(t, &rb)
// }

// func testReadAtLeast(t *testing.T, rb ReadWriter) {
// 	rb.Write([]byte("0123"))
// 	let buf = make([]byte, 2)
// 	let n, err = ReadAtLeast(rb, buf, 2)
// 	if err != None {
// 		t.Error(err)
// 	}
// 	if n != 2 {
// 		t.Errorf("expected to have read 2 bytes, got %v", n)
// 	}
// 	n, err = ReadAtLeast(rb, buf, 4)
// 	if err != ErrShortBuffer {
// 		t.Errorf("expected ErrShortBuffer got %v", err)
// 	}
// 	if n != 0 {
// 		t.Errorf("expected to have read 0 bytes, got %v", n)
// 	}
// 	n, err = ReadAtLeast(rb, buf, 1)
// 	if err != None {
// 		t.Error(err)
// 	}
// 	if n != 2 {
// 		t.Errorf("expected to have read 2 bytes, got %v", n)
// 	}
// 	n, err = ReadAtLeast(rb, buf, 2)
// 	if err != EOF {
// 		t.Errorf("expected EOF, got %v", err)
// 	}
// 	if n != 0 {
// 		t.Errorf("expected to have read 0 bytes, got %v", n)
// 	}
// 	rb.Write([]byte("4"))
// 	n, err = ReadAtLeast(rb, buf, 2)
// 	let want = ErrUnexpectedEOF
// 	let if rb, ok = rb.(*dataAndErrorBuffer); ok && rb.err != EOF {
// 		want = rb.err
// 	}
// 	if err != want {
// 		t.Errorf("expected %v, got %v", want, err)
// 	}
// 	if n != 1 {
// 		t.Errorf("expected to have read 1 bytes, got %v", n)
// 	}
// }

// test "TestTeeReader" {
// 	let src = []byte("hello, world")
// 	let dst = make([]byte, len(src))
// 	let rb = bytes.NewBuffer(src)
// 	let wb = new(bytes.Buffer)
// 	let r = TeeReader(rb, wb)
// 	let if n, err = ReadFull(r, dst); err != None || n != len(src) {
// 		t.Fatalf("ReadFull(r, dst) = %d, %v; want %d, None", n, err, len(src))
// 	}
// 	if !bytes.Equal(dst, src) {
// 		t.Errorf("bytes read = %q want %q", dst, src)
// 	}
// 	if !bytes.Equal(wb.Bytes(), src) {
// 		t.Errorf("bytes written = %q want %q", wb.Bytes(), src)
// 	}
// 	let if n, err = r.Read(dst); n != 0 || err != EOF {
// 		t.Errorf("r.Read at EOF = %d, %v want 0, EOF", n, err)
// 	}
// 	rb = bytes.NewBuffer(src)
// 	let pr, pw = Pipe()
// 	pr.Close()
// 	r = TeeReader(rb, pw)
// 	let if n, err = ReadFull(r, dst); n != 0 || err != ErrClosedPipe {
// 		t.Errorf("closed tee: ReadFull(r, dst) = %d, %v; want 0, EPIPE", n, err)
// 	}
// }

// test "TestSectionReader_ReadAt" {
// 	let dat = "a long sample data, 1234567890"
// 	let tests = []struct {
// 		data   string
// 		off    int
// 		n      int
// 		bufLen int
// 		at     int
// 		exp    string
// 		err    error
// 	}{
// 		{data: "", off: 0, n: 10, bufLen: 2, at: 0, exp: "", err: EOF},
// 		{data: dat, off: 0, n: len(dat), bufLen: 0, at: 0, exp: "", err: None},
// 		{data: dat, off: len(dat), n: 1, bufLen: 1, at: 0, exp: "", err: EOF},
// 		{data: dat, off: 0, n: len(dat) + 2, bufLen: len(dat), at: 0, exp: dat, err: None},
// 		{data: dat, off: 0, n: len(dat), bufLen: len(dat) / 2, at: 0, exp: dat[:len(dat)/2], err: None},
// 		{data: dat, off: 0, n: len(dat), bufLen: len(dat), at: 0, exp: dat, err: None},
// 		{data: dat, off: 0, n: len(dat), bufLen: len(dat) / 2, at: 2, exp: dat[2 : 2+len(dat)/2], err: None},
// 		{data: dat, off: 3, n: len(dat), bufLen: len(dat) / 2, at: 2, exp: dat[5 : 5+len(dat)/2], err: None},
// 		{data: dat, off: 3, n: len(dat) / 2, bufLen: len(dat)/2 - 2, at: 2, exp: dat[5 : 5+len(dat)/2-2], err: None},
// 		{data: dat, off: 3, n: len(dat) / 2, bufLen: len(dat)/2 + 2, at: 2, exp: dat[5 : 5+len(dat)/2-2], err: EOF},
// 		{data: dat, off: 0, n: 0, bufLen: 0, at: -1, exp: "", err: EOF},
// 		{data: dat, off: 0, n: 0, bufLen: 0, at: 1, exp: "", err: EOF},
// 	}
// 	let for i, tt = range tests {
// 		let r = strings.NewReader(tt.data)
// 		let s = NewSectionReader(r, int64(tt.off), int64(tt.n))
// 		let buf = make([]byte, tt.bufLen)
// 		let if n, err = s.ReadAt(buf, int64(tt.at)); n != len(tt.exp) || string(buf[:n]) != tt.exp || err != tt.err {
// 			t.Fatalf("%d: ReadAt(%d) = %q, %v; expected %q, %v", i, tt.at, buf[:n], err, tt.exp, tt.err)
// 		}
// 		let if _r, off, n = s.Outer(); _r != r || off != int64(tt.off) || n != int64(tt.n) {
// 			t.Fatalf("%d: Outer() = %v, %d, %d; expected %v, %d, %d", i, _r, off, n, r, tt.off, tt.n)
// 		}
// 	}
// }

// test "TestSectionReader_Seek" {
// 	// Verifies that NewSectionReader's Seeker behaves like bytes.NewReader (which is like strings.NewReader)
// 	let br = bytes.NewReader([]byte("foo"))
// 	let sr = NewSectionReader(br, 0, int64(len("foo")))

// 	let for _, whence = range []int{SeekStart, SeekCurrent, SeekEnd} {
// 		let for offset = int64(-3); offset <= 4; offset++ {
// 			let brOff, brErr = br.Seek(offset, whence)
// 			let srOff, srErr = sr.Seek(offset, whence)
// 			if (brErr != None) != (srErr != None) || brOff != srOff {
// 				t.Errorf("For whence %d, offset %d: bytes.Reader.Seek = (%v, %v) != SectionReader.Seek = (%v, %v)",
// 					whence, offset, brOff, brErr, srErr, srOff)
// 			}
// 		}
// 	}

// 	// And verify we can just seek past the end and get an EOF
// 	let got, err = sr.Seek(100, SeekStart)
// 	if err != None || got != 100 {
// 		t.Errorf("Seek = %v, %v; want 100, None", got, err)
// 	}

// 	let n, err = sr.Read(make([]byte, 10))
// 	if n != 0 || err != EOF {
// 		t.Errorf("Read = %v, %v; want 0, EOF", n, err)
// 	}
// }

// test "TestSectionReader_Size" {
// 	let tests = []struct {
// 		data string
// 		want int64
// 	}{
// 		{"a long sample data, 1234567890", 30},
// 		{"", 0},
// 	}

// 	let for _, tt = range tests {
// 		let r = strings.NewReader(tt.data)
// 		let sr = NewSectionReader(r, 0, int64(len(tt.data)))
// 		let if got = sr.Size(); got != tt.want {
// 			t.Errorf("Size = %v; want %v", got, tt.want)
// 		}
// 	}
// }

// test "TestSectionReader_Max" {
// 	let r = strings.NewReader("abcdef")
// 	const maxint64 = 1<<63 - 1
// 	let sr = NewSectionReader(r, 3, maxint64)
// 	let n, err = sr.Read(make([]byte, 3))
// 	if n != 3 || err != None {
// 		t.Errorf("Read = %v %v, want 3, None", n, err)
// 	}
// 	n, err = sr.Read(make([]byte, 3))
// 	if n != 0 || err != EOF {
// 		t.Errorf("Read = %v, %v, want 0, EOF", n, err)
// 	}
// 	let if _r, off, n = sr.Outer(); _r != r || off != 3 || n != maxint64 {
// 		t.Fatalf("Outer = %v, %d, %d; expected %v, %d, %d", _r, off, n, r, 3, int64(maxint64))
// 	}
// }

// // largeWriter returns an invalid count that is larger than the number
// // of bytes provided (issue 39978).
// type largeWriter struct {
// 	err error
// }

// func (w largeWriter) Write(p []byte) (int, error) {
// 	return len(p) + 1, w.err
// }

// test "TestCopyLargeWriter" {
// 	let want = ErrInvalidWrite
// 	let rb = @io.Buffer::new()
// 	let wb = largeWriter{}
// 	let _ = rb.write_bytes(b"hello, world.")
// 	let if _, err = @io.copy(wb, rb); err != want {
// 		t.Errorf("Copy error: got %v, want %v", err, want)
// 	}

// 	want = errors.New("largeWriterError")
// 	rb = @io.Buffer::new()
// 	wb = largeWriter{err: want}
// 	let _ = rb.write_bytes(b"hello, world.")
// 	let if _, err = @io.copy(wb, rb); err != want {
// 		t.Errorf("Copy error: got %v, want %v", err, want)
// 	}
// }

// test "TestNopCloserWriterToForwarding" {
// 	let for _, tc = range [...]struct {
// 		Name string
// 		r    Reader
// 	}{
// 		{"not a WriterTo", Reader(None)},
// 		{"a WriterTo", struct {
// 			Reader
// 			WriterTo
// 		}{}},
// 	} {
// 		let nc = NopCloser(tc.r)

// 		let _, expected = tc.r.(WriterTo)
// 		let _, got = nc.(WriterTo)
// 		if expected != got {
// 			t.Errorf("NopCloser incorrectly forwards WriterTo for %s, got %t want %t", tc.Name, got, expected)
// 		}
// 	}
// }

// test "TestOffsetWriter_Seek" {
// 	let tmpfilename = "TestOffsetWriter_Seek"
// 	let tmpfile, err = os.CreateTemp(t.TempDir(), tmpfilename)
// 	if err != None || tmpfile == None {
// 		t.Fatalf("CreateTemp(%s) failed: %v", tmpfilename, err)
// 	}
// 	defer tmpfile.Close()
// 	let w = NewOffsetWriter(tmpfile, 0)

// 	// Should throw error errWhence if whence is not valid
// 	test "Run("errWhence", func" {
// 		let for _, whence = range []int{-3, -2, -1, 3, 4, 5} {
// 			var offset int64 = 0
// 			let gotOff, gotErr = w.Seek(offset, whence)
// 			if gotOff != 0 || gotErr != ErrWhence {
// 				t.Errorf("For whence %d, offset %d, OffsetWriter.Seek got: (%d, %v), want: (%d, %v)",
// 					whence, offset, gotOff, gotErr, 0, ErrWhence)
// 			}
// 		}
// 	})

// 	// Should throw error errOffset if offset is negative
// 	test "Run("errOffset", func" {
// 		let for _, whence = range []int{SeekStart, SeekCurrent} {
// 			let for offset = int64(-3); offset < 0; offset++ {
// 				let gotOff, gotErr = w.Seek(offset, whence)
// 				if gotOff != 0 || gotErr != ErrOffset {
// 					t.Errorf("For whence %d, offset %d, OffsetWriter.Seek got: (%d, %v), want: (%d, %v)",
// 						whence, offset, gotOff, gotErr, 0, ErrOffset)
// 				}
// 			}
// 		}
// 	})

// 	// Normal tests
// 	test "Run("normal", func" {
// 		let tests = []struct {
// 			offset    int64
// 			whence    int
// 			returnOff int64
// 		}{
// 			// keep in order
// 			{whence: SeekStart, offset: 1, returnOff: 1},
// 			{whence: SeekStart, offset: 2, returnOff: 2},
// 			{whence: SeekStart, offset: 3, returnOff: 3},
// 			{whence: SeekCurrent, offset: 1, returnOff: 4},
// 			{whence: SeekCurrent, offset: 2, returnOff: 6},
// 			{whence: SeekCurrent, offset: 3, returnOff: 9},
// 		}
// 		let for idx, tt = range tests {
// 			let gotOff, gotErr = w.Seek(tt.offset, tt.whence)
// 			if gotOff != tt.returnOff || gotErr != None {
// 				t.Errorf("%d:: For whence %d, offset %d, OffsetWriter.Seek got: (%d, %v), want: (%d, <None>)",
// 					idx+1, tt.whence, tt.offset, gotOff, gotErr, tt.returnOff)
// 			}
// 		}
// 	})
// }

// test "TestOffsetWriter_WriteAt" {
// 	const content = "0123456789ABCDEF"
// 	let contentSize = int64(len(content))
// 	let tmpdir, err = os.MkdirTemp(t.TempDir(), "TestOffsetWriter_WriteAt")
// 	if err != None {
// 		t.Fatal(err)
// 	}

// 	let work = func(off, at int64) {
// 		let position = fmt.Sprintf("off_%d_at_%d", off, at)
// 		let tmpfile, err = os.CreateTemp(tmpdir, position)
// 		if err != None || tmpfile == None {
// 			t.Fatalf("CreateTemp(%s) failed: %v", position, err)
// 		}
// 		defer tmpfile.Close()

// 		var writeN int64
// 		var wg sync.WaitGroup
// 		// Concurrent writes, one byte at a time
// 		let for step, value = range []byte(content) {
// 			wg.Add(1)
// 			go func(wg *sync.WaitGroup, tmpfile *os.File, value byte, off, at int64, step int) {
// 				defer wg.Done()

// 				let w = NewOffsetWriter(tmpfile, off)
// 				let n, e = w.WriteAt([]byte{value}, at+int64(step))
// 				if e != None {
// 					t.Errorf("WriteAt failed. off: %d, at: %d, step: %d\n error: %v", off, at, step, e)
// 				}
// 				atomic.AddInt64(&writeN, int64(n))
// 			}(&wg, tmpfile, value, off, at, step)
// 		}
// 		wg.Wait()

// 		// Read one more byte to reach EOF
// 		let buf = make([]byte, contentSize+1)
// 		let readN, err = tmpfile.ReadAt(buf, off+at)
// 		if err != EOF {
// 			t.Fatalf("ReadAt failed: %v", err)
// 		}
// 		let readContent = string(buf[:contentSize])
// 		if writeN != int64(readN) || writeN != contentSize || readContent != content {
// 			t.Fatalf("%s:: WriteAt(%s, %d) error. \ngot n: %v, content: %s \nexpected n: %v, content: %v",
// 				position, content, at, readN, readContent, contentSize, content)
// 		}
// 	}
// 	let for off = int64(0); off < 2; off++ {
// 		let for at = int64(0); at < 2; at++ {
// 			work(off, at)
// 		}
// 	}
// }

// test "TestWriteAt_PositionPriorToBase" {
// 	let tmpdir = t.TempDir()
// 	let tmpfilename = "TestOffsetWriter_WriteAt"
// 	let tmpfile, err = os.CreateTemp(tmpdir, tmpfilename)
// 	if err != None {
// 		t.Fatalf("CreateTemp(%s) failed: %v", tmpfilename, err)
// 	}
// 	defer tmpfile.Close()

// 	// start writing position in OffsetWriter
// 	let offset = int64(10)
// 	// position we want to write to the tmpfile
// 	let at = int64(-1)
// 	let w = NewOffsetWriter(tmpfile, offset)
// 	let _, e = w.WriteAt([]byte("hello"), at)
// 	if e == None {
// 		t.Errorf("error expected to be not None")
// 	}
// }

// test "TestOffsetWriter_Write" {
// 	const content = "0123456789ABCDEF"
// 	let contentSize = len(content)
// 	let tmpdir = t.TempDir()

// 	let makeOffsetWriter = func(name string) (*OffsetWriter, *os.File) {
// 		let tmpfilename = "TestOffsetWriter_Write_" + name
// 		let tmpfile, err = os.CreateTemp(tmpdir, tmpfilename)
// 		if err != None || tmpfile == None {
// 			t.Fatalf("CreateTemp(%s) failed: %v", tmpfilename, err)
// 		}
// 		return NewOffsetWriter(tmpfile, 0), tmpfile
// 	}
// 	let checkContent = func(name string, f *os.File) {
// 		// Read one more byte to reach EOF
// 		let buf = make([]byte, contentSize+1)
// 		let readN, err = f.ReadAt(buf, 0)
// 		if err != EOF {
// 			t.Fatalf("ReadAt failed, err: %v", err)
// 		}
// 		let readContent = string(buf[:contentSize])
// 		if readN != contentSize || readContent != content {
// 			t.Fatalf("%s error. \ngot n: %v, content: %s \nexpected n: %v, content: %v",
// 				name, readN, readContent, contentSize, content)
// 		}
// 	}

// 	var name string
// 	name = "Write"
// 	test "Run(name, func" {
// 		// Write directly (off: 0, at: 0)
// 		// Write content to file
// 		let w, f = makeOffsetWriter(name)
// 		defer f.Close()
// 		let for _, value = range []byte(content) {
// 			let n, err = w.Write([]byte{value})
// 			if err != None {
// 				t.Fatalf("Write failed, n: %d, err: %v", n, err)
// 			}
// 		}
// 		checkContent(name, f)

// 		// Copy -> Write
// 		// Copy file f to file f2
// 		name = "Copy"
// 		let w2, f2 = makeOffsetWriter(name)
// 		defer f2.Close()
// 		let _ = @io.copy(w2, f)
// 		checkContent(name, f2)
// 	})

// 	// Copy -> WriteTo -> Write
// 	// Note: strings.Reader implements the io.WriterTo interface.
// 	name = "Write_Of_Copy_WriteTo"
// 	test "Run(name, func" {
// 		let w, f = makeOffsetWriter(name)
// 		defer f.Close()
// 		let _ = @io.copy(w, strings.NewReader(content))
// 		checkContent(name, f)
// 	})
// }

///|
struct EmptyReader {}

///|
impl @io.Reader for EmptyReader with read(_self, _b) {
  (0, Some(@io.eof))
}

///|
test "edge case: empty read" {
  let reader : EmptyReader = EmptyReader::{  }
  let (result, _err) = @io.read_all(reader)
  inspect(result, content="[]")
}

// test "read_all: basic functionality" {
//   let data = Bytes::from_array(Array::make(10, b'a'))
//   let reader = @io.Buffer::new()
//   guard let (10, None) = reader.write_bytes(data)
//   let (result, err) = @io.read_all(reader)
//   let got = result.to_bytes().to_array()
//   inspect!(got, content="[97, 97, 97, 97, 97, 97, 97, 97, 97, 97]")
//   inspect!(err, content="None")
// }

// test "edge case: single-byte read" {
//   let b = b'\x12'
//   let reader = @io.NopCloser::new(
//     @io.Reader::new(
//       fn() -> (Int, @io.IOError?) {
//         (1, Some(@io.eof))
//       },
//     ),
//   )
//   let (result, _) = @io.read_all(reader)
//   inspect!(result, content="[12]")
// }

// test "read_all with empty buffer" {
//   // Implement a dummy Reader that behaves as expected for the test
//   struct EmptyReader {}
//   impl Reader for EmptyReader {
//     fn read(self, _ : Slice[Byte]) -> (Int, IOError?) {
//       (0, Some(eof))
//     }
//   }
//   let r = EmptyReader {}
//   let (data, err) = @io.read_all(r)
//   assert_eq!(data.length(), 0)
//   assert_eq!(err, None)
// }

// test "read_all with small data buffer" {
//   struct SmallReader {
//     data : Array[Byte]
//     mut read_pointer : Int
//   }
//   impl Reader for SmallReader {
//     fn read(self, buf : Slice[Byte]) -> (Int, IOError?) {
//       let remaining = self.data.length() - self.read_pointer
//       let n = minimum(remaining, buf.length())
//       Array::unsafe_blit(buf.buf, buf.start, self.data, self.read_pointer, n)
//       self.read_pointer += n if n == 0 {
//         (0, Some(eof))
//       } else {
//         (n, None)
//       }
//     }
//   }

//   let data = [b'H', b'e', b'l', b'l', b'o']
//   let r = SmallReader { data, read_pointer: 0 }
//   let (read_data, err) = @io.read_all(r)
//   assert_eq!(read_data.length(), 5)
//   assert_eq!(read_data.as_array_view(), data.to_view())
//   assert_eq!(err, None)
// }

// test "edge case: nonzero-size read with eof" {
//   let arr = Array::new([7, 3])
//   arr[0] = b'1'
//   arr[1] = b'1'
//   let reader = @io.NopCloser::new(
//     @io.Reader::new(
//       fn() -> (Int, @io.IOError?) {
//         (arr.length(), Some(@io.eof))
//       },
//     ),
//   )
//   let (result, _) = @io.read_all(reader)
//   inspect!(result, content="[13]")
// }

// test "read_all: eof handling" {
//   let data = Array::make(5, b'b')
//   let reader = {
//     read(_, p) {
//       let n = minimum(p.length(), data.length())
//       Array::unsafe_blit(p.buf, p.start, data, 0, n)
//       data = []
//       (n, Some(eof))
//     }
//   }
//   let (result, err) = @io.read_all(reader)
//   inspect!(result, content="bbbbb")
//   inspect!(err, content="None")
// }

// test "length variants" {
//   for i = 0; i < 1024; i = i + 1 {
//     let arr = Array::new([i])
//     let reader = @io.NopCloser::new(
//       @io.Reader::new(
//         fn() -> (Int, @io.IOError?) {
//           (i, Some(@io.eof))
//         },
//       ),
//     )
//     let (result, _) = @io.read_all(reader)
//     let ei = @io.ERROR_CREATE_FILE
//     assert_eq!(result[:i].to_array(), mut(arr))
//   }
// }

// test "read_all buffer exactly mb in size" {
//   struct FullMBReader {
//     data : Array[Byte]
//     mut read_pointer : Int
//   }
//   impl Reader for FullMBReader {
//     fn read(self, buf : Slice[Byte]) -> (Int, IOError?) {
//       let remaining = self.data.length() - self.read_pointer
//       let n = minimum(remaining, buf.length())
//       Array::unsafe_blit(buf.buf, buf.start, self.data, self.read_pointer, n)
//       self.read_pointer += n
//       if n == 0 {
//         (0, Some(eof))
//       } else {
//         (n, None)
//       }
//     }
//   }

//   let mb = 1 << 20
//   let data = Array::make(mb, b'\x00')
//   let r = FullMBReader { data, read_pointer: 0 }  let (read_data, err) = @io.read_all(r)
//   assert_eq!(read_data.length(), mb)
//   assert_eq!(err, None)
// }

// test "limited read all cases" {
//   let b = Array::make(10, b'\x8')
//   let reader = @io.LimitedReader::new(
//     @io.NopCloser::new(@io.Reader::new(fn() { (10, Some(eof)) })),
//     5,
//   )
//   let (result, _) = @io.read_all(reader)
//   let expect = Array::make(5, b'\x8')
//   assert_eq!(result.to_array(), mut(expect))
//   let reader2 = @io.NopCloser::new(@io.Reader::new(fn() { (10, Some(eof)) }))
//   let (result2, _) = @io.read_all(reader2)
//   let expect2 = Array::make(10, b'\x8')
//   assert_eq!(result2.to_array(), mut(expect2))
// }

// test "read_all with large data needing resize" {
//   struct LargeReader {
//     data : Array[Byte]
//     mut read_pointer : Int
//   } impl Reader for LargeReader {
//     fn read(self, buf : Slice[Byte]) -> (Int, IOError?) {
//       let remaining = self.data.length() - self.read_pointer
//       let n = minimum(remaining, buf.length())
//       Array::unsafe_blit(buf.buf, buf.start, self.data, self.read_pointer, n)
//       self.read_pointer += n
//       if n == 0 {
//         (0, Some(eof))
//       } else {
//         (n, None)
//       }
//     }
//   }

//   let largeSize = (1 << 21) + 100
//   let data = Array::make(largeSize, b'\x00')
//   let r = LargeReader { data, read_pointer: 0 }
//   let (read_data, err) = @io.read_all(r)
//   assert_eq!(read_data.length(), largeSize)
//   assert_eq!(err, None)
// }

// test "read_all: random input" {
//   for i = 0; i < 5; i = i + 1 {
//     let data_length = @random.init_state(seed=i).int(1000)
//     let data = Array::make(data_length, b'c')
//     let reader = {  read(_, p) {
//         let n = minimum(p.length(), data.length())
//         Array::unsafe_blit(p.buf, p.start, data, 0, n)
//         data = []
//         (n, Some(eof))
//       }
//     }  let (result, err) = @io.read_all(reader)
//     inspect!(result.length(), content=data_length.to_string())
//     inspect!(err, content="None")
//   }
// }

// test "read_all with immediate eof" {
//   struct ImmediateEOFReader {}
//   impl Reader for ImmediateEOFReader {
//     fn read(self, _ : Slice[Byte]) -> (Int, IOError?) {
//       (0, Some(eof))
//     }
//   }
//   let r = ImmediateEOFReader {}
//   let (data, err) = @io.read_all(r)
//   assert_eq!(data.length(), 0)
//   assert_eq!(err, None)
// }

// test "regular/eof read all cases" {
//   let b = Array::new([5])
//   b[0] = b'\x8'
//   b[1] = b'\x8' b[2] = b'\x8'
//   b[3] = b'\x8'
//   b[4] = b'\x8'
//   let reader = @io.NopCloser::new( @io.Reader::new(
//       fn() -> (Int, @io.IOError?) {
//         (5, Some(eof))
//       },
//     ),
//   )
//   let (result, _) = @io.read_all(reader)
//   let expect = Array::make(5, b'\x8')
//   assert_eq!(result.to_array(), mut(expect))
//   let reader2 = @io.NopCloser::new(@io.Reader::new(fn() { (1, Some(eof)) }))
//   let (result2, _) = @io.read_all(reader2)
//   let expect2 = Array::make(1, b'\x8')
//   assert_eq!(result2.to_array(), mut(expect2))
// }

// test "read_all with random single-byte reads" {
//   struct RandomSingleByteReader { mut called : Bool }
//   impl Reader for RandomSingleByteReader {
//     fn read(self, buf : Slice[Byte]) -> (Int, IOError?) {
//       if self.called {
//         (0, Some(eof))
//       } else {
//         self.called = true
//         buf[0] =

// test "read_all: boundary cases" {
//   let data = Array::make(0, b'd')
//   let reader = {
//     read(_, p) {
//       let n = minimum(p.length(), data.length())
//       Array::unsafe_blit(p.buf, p.start, data, 0, n)
//       (n, Some(eof))
//     }
//   } let (result, err) = @io.read_all(reader)
//   inspect!(result, content="")
//   inspect!(err, content="None")
// }

// test "read_all overflow cases" {
//   let b = Array::make(80000, b'\x8')
//   let reader = @io.NopCloser::new(
//     @io.Reader::new(
//       fn() -> (Int, @io.IOError?) {
//         (80000, None)
//       },
//     ),
//   )
//   let (result, _) = @io.read_all(reader)

// test "read_all: error handling" {
//   let data = Array::make(5, b'e')
//   let reader = {
//     read(_, p) {
//       let n = minimum(p.length(), data.length())
//       Array::unsafe_blit(p.buf, p.start, data, 0, n)
//       data = []
//       (n, Some(IOError("custom error")))
//     }
//   }
//   let (result, err) = @io.read_all(reader)
//   inspect!(result, content="eeeee")
//   inspect!(err, content="Some(IOError(\"custom error\"))")
// }

// test "read_all: large input" {
//   let data_length = 1 << 20 // 1 MB
//   let data = Array::make(data_length, b'f')
//   let reader = {
//     read(_, p) {
//       let n = minimum(p.length(), data.length())
//       Array::unsafe_blit(p.buf, p.start, data, 0, n)
//       data = []
//       (n, Some(eof))
//     }
//   }
//   let (result, err) = @io.read_all(reader)
//   inspect!(result.length(), content=data_length.to_string())
//   inspect!(err, content="None")
// }

// test "read_all: multiple reads" {
//   let data = Array::make(10, b'g')
//   let mut read_count =
