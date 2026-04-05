# MoonBit FFI

A lightweight utility library for converting between C‐style null-terminated
byte strings (`Bytes`) and MoonBit `String` values.

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)]()

## Features

- **from_cstr**: Convert a null-terminated `Bytes` to a MoonBit `String` (drops
  the `\x00` terminator).
- **to_cstr**: Convert a MoonBit `String` to null-terminated `Bytes`.

## Installation

Add `justjavac/ffi` to your dependencies:

```shell
moon update
moon add justjavac/ffi
```

## Usage

```moonbit
// Convert Bytes → String
let data = b"Hello, world!\x00"
let s = @ffi.from_cstr(data)
assert_eq!(s, "Hello, world!")

// Convert String → Bytes
let cstr = @ffi.to_cstr("Hello, world!")
assert_eq!(cstr, data)
```

## Supported Backends

- Wasm & WasmGC
- JavaScript
- Native
- LLVM

## Development

Build the library and run tests (including docs):

```shell
moon build
moon test --doc
```

## License

This project is licensed under the MIT License.\
© justjavac
