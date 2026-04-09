///|
/// copy_json copies bytes from a source reader until a valid JSON value is completed.
/// It returns the Json value, the number of bytes copied, and any error that occurred during the process.
pub fn copy_json(src : &ByteReader) -> (Json, Int64, IOError?) {
  let ctx = ParseContext::make(src)
  let val = ctx.parse_value() catch {
    ParseError(e) => return (Json::null(), 0, Some(IOError(e.to_string())))
  }
  (val, ctx.offset.to_int64(), None)
}

// The following code is based upon: https://github.com/moonbitlang/core/blob/main/json/parse.mbt
// which has the following license:
// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
priv suberror ParseError {
  ParseError(String)
} derive(Debug)

///|
fn ParseContext::parse_value(ctx : ParseContext) -> Json raise ParseError {
  let tok = ctx.lex_value(allow_rbracket=false)
  ctx.parse_value2(tok)
}

///|
fn ParseContext::parse_value2(
  ctx : ParseContext,
  tok : Token,
) -> Json raise ParseError {
  match tok {
    Null => Json::null()
    True => true.to_json()
    False => false.to_json()
    Number(n) => n.to_json()
    String(s) => s.to_json()
    LBrace => ctx.parse_object()
    LBracket => ctx.parse_array()
    RBracket | RBrace | Comma =>
      raise ParseError(
        "invalid JSON: unexpected '\{tok.to_repr()}' at offset \{ctx.offset}",
      )
  }
}

///|
fn ParseContext::parse_object(ctx : ParseContext) -> Json raise ParseError {
  let map = Map::new()
  for ;; {
    match ctx.lex_property_name() {
      RBrace => return map.to_json()
      String(name) => {
        ctx.lex_after_property_name()
        map[name] = ctx.parse_value()
        match ctx.lex_after_object_value() {
          Comma => ()
          RBrace => return map.to_json()
          tok =>
            raise ParseError(
              "invalid JSON: expected ',' or '}' at offset \{ctx.offset}, got '\{tok.to_repr()}'",
            )
        }
      }
      tok =>
        raise ParseError(
          "invalid JSON: expected '}' or property name at offset \{ctx.offset}, got '\{tok.to_repr()}'",
        )
    }
  }
}

///|
fn ParseContext::parse_array(ctx : ParseContext) -> Json raise ParseError {
  let vec = []
  for ;; {
    match ctx.lex_value(allow_rbracket=true) {
      RBracket => return vec.to_json()
      tok => {
        vec.push(ctx.parse_value2(tok))
        let tok2 = ctx.lex_after_array_value()
        match tok2 {
          Comma => ()
          RBracket => return vec.to_json()
          _ =>
            raise ParseError(
              "unexpected '\{tok2.to_repr()}' at offset \{ctx.offset}",
            )
        }
      }
    }
  }
}

///|
priv struct ParseContext {
  r : &ByteReader
  buf : Buffer
  mut offset : Int
}

///|
const DEFAULT_BUFFER_SIZE = 1024

///|
fn ParseContext::make(r : &ByteReader) -> ParseContext {
  { r, buf: Buffer::new(size_hint=DEFAULT_BUFFER_SIZE), offset: 0 }
}

///|
priv struct CharClass(Array[(Char, Char)])

///|
fn CharClass::of(array : Array[(Char, Char)]) -> CharClass {
  CharClass(array)
}

///|
fn CharClass::contains(self : CharClass, c : Char) -> Bool {
  for left = 0, right = self.0.length(); left < right; {
    let middle = (left + right) / 2
    let (min, max) = self.0[middle]
    if c < min {
      continue left, middle
    } else if c > max {
      continue middle + 1, right
    } else {
      break true
    }
  } nobreak {
    false
  }
}

///|
priv enum Token {
  Null
  True
  False
  Number(Double)
  String(String)
  LBrace
  RBrace
  LBracket
  RBracket
  Comma
  // Colon
} derive(Debug)

///|
let non_ascii_whitespace : CharClass = CharClass::of([
  ('\u00A0', '\u00A0'),
  ('\u1680', '\u1680'),
  ('\u2000', '\u200A'),
  ('\u2028', '\u2029'),
  ('\u202F', '\u202F'),
  ('\u205F', '\u205F'),
  ('\u3000', '\u3000'),
  ('\uFEFF', '\uFEFF'),
])

///|
fn ParseContext::lex_value(
  ctx : ParseContext,
  allow_rbracket~ : Bool,
) -> Token raise ParseError {
  for ;; {
    match ctx.read_char() {
      Some('\t' | ' ' | '\n' | '\r') => continue
      Some('{') => return LBrace
      Some('[') => return LBracket
      Some(']') =>
        if allow_rbracket {
          return RBracket
        } else {
          ctx.invalid_char(']', shift=-1)
        }
      Some('n') => {
        ctx.expect_ascii_char(b'u')
        ctx.expect_ascii_char(b'l')
        ctx.expect_ascii_char(b'l')
        return Null
      }
      Some('t') => {
        ctx.expect_ascii_char(b'r')
        ctx.expect_ascii_char(b'u')
        ctx.expect_ascii_char(b'e')
        return True
      }
      Some('f') => {
        ctx.expect_ascii_char(b'a')
        ctx.expect_ascii_char(b'l')
        ctx.expect_ascii_char(b's')
        ctx.expect_ascii_char(b'e')
        return False
      }
      Some('-') =>
        match ctx.read_char() {
          Some('0') => {
            let n = ctx.lex_zero(start=ctx.offset - 2)
            return Number(n)
          }
          Some(c2) => {
            if c2 is ('1'..='9') {
              let n = ctx.lex_decimal_integer(start=ctx.offset - 2)
              return Number(n)
            }
            ctx.invalid_char(c2, shift=-1)
          }
          None => raise ParseError("invalid eof")
        }
      Some('0') => {
        let n = ctx.lex_zero(start=ctx.offset - 1)
        return Number(n)
      }
      Some('1'..='9') => {
        let n = ctx.lex_decimal_integer(start=ctx.offset - 1)
        return Number(n)
      }
      Some('"') => {
        let s = ctx.lex_string()
        return String(s)
      }
      Some(c) => {
        if c > '\u{7f}' && non_ascii_whitespace.contains(c) {
          continue
        }
        ctx.invalid_char(c, shift=-1)
      }
      None => raise ParseError("invalid eof") // InvalidEof
    }
  }
}

///|
fn[T] ParseContext::invalid_char(
  ctx : ParseContext,
  c : Char,
  shift? : Int = 0,
) -> T raise ParseError {
  ctx.offset += shift
  raise ParseError("invalid JSON: unexpected '\{c}' at offset \{ctx.offset}")
}

///|
fn ParseContext::read_new_byte(self : ParseContext) -> Char? {
  let (b, err) = self.r.read_byte()
  guard err is None else { return None }
  self.offset += 1
  let (_, err) = self.buf.write_byte(b)
  guard err is None else { return None }
  let current = Int::unsafe_to_char(b.to_int())
  Some(current)
}

///|
fn ParseContext::read_char(ctx : ParseContext) -> Char? {
  if ctx.offset < ctx.buf.length() {
    let b = ctx.buf[ctx.offset]
    ctx.offset += 1
    return Some(Int::unsafe_to_char(b.to_int()))
  }
  ParseContext::read_new_byte(ctx)
}

///|
/// low surrogate
// const SURROGATE_LOW_CHAR = 0xD800

///|
/// high surrogate
// const SURROGATE_HIGH_CHAR = 0xDFFF

///|
/// `ctx.expect_char(c)` check the current context is c,
/// if it is, consume the character and return `()`,
/// otherwise raise an error, when it is an error, the position is unspecified.
fn ParseContext::expect_char(
  ctx : ParseContext,
  c : Char,
) -> Unit raise ParseError {
  // guard ctx.offset < ctx.end_offset else { raise ParseError("invalid eof") }
  // let c1 = ctx.input.unsafe_charcode_at(ctx.offset)
  // ctx.offset += 1
  guard ParseContext::read_char(ctx) is Some(c1) else {
    raise ParseError("invalid eof")
  }
  if c != c1 {
    raise ParseError(
      "invalid JSON: unexpected '\{c1}' at offset \{ctx.offset}, wanted '\{c}'",
    )
  }
  // let c0 = c.to_int()
  // if c0 < 0xFFFF {
  //   // c0 < SURROGATE_LOW_CHAR || c0 is (0xE000..=0XFFFF)
  //   // c0 is a valid char so only need check if c0<0xFFFF is BMP code point
  //   if c0 != c1 {
  //     ctx.invalid_char!(c0, shift=-1)
  //   }
  // } else {
  //   // c0 is not bmp code point
  //   // c1 has to be surrogate pair otherwise it is invalid
  //   guard c1 is (SURROGATE_LOW_CHAR..=SURROGATE_HIGH_CHAR) &&
  //     ctx.offset < ctx.end_offset else {
  //     ctx.invalid_char!(c1, shift=-1)
  //   }
  //   let c2 = ctx.input.unsafe_charcode_at(ctx.offset)
  //   let c3 = (c1 << 10) + c2 - 0x35fdc00
  //   if c3 != c0 {
  //     ctx.invalid_char!(c3, shift=-1)
  //   } else {
  //     ctx.offset += 1 // consume and move forward
  //   }
  // }
}

///|
/// `ctx.expect_ascii_char(c)` check the current context is c,
///
fn ParseContext::expect_ascii_char(
  ctx : ParseContext,
  c : Byte,
) -> Unit raise ParseError {
  // guard ctx.offset < ctx.end_offset else { raise ParseError("invalid eof") }
  // let c1 = ctx.input.unsafe_charcode_at(ctx.offset)
  // ctx.offset += 1
  // if c.to_int() != c1 {
  //   ctx.invalid_char!(c, shift=-1)
  // }
  ParseContext::expect_char(ctx, Int::unsafe_to_char(c.to_int()))
}

///|
fn ParseContext::lex_skip_whitespace(ctx : ParseContext) -> Unit {
  for ;; {
    match ctx.read_char() {
      Some('\t' | ' ' | '\n' | '\r') => continue
      Some(c) => {
        if c > '\u{7f}' && non_ascii_whitespace.contains(c) {
          continue
        }
        ctx.offset -= 1
        break
      }
      None => break
    }
  }
}

///|
fn ParseContext::lex_after_array_value(
  ctx : ParseContext,
) -> Token raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some(']') => RBracket
    Some(',') => Comma
    Some(c) => ctx.invalid_char(c, shift=-1)
    None => raise ParseError("invalid eof")
  }
}

///|
fn ParseContext::lex_after_property_name(
  ctx : ParseContext,
) -> Unit raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some(':') => ()
    Some(c) => ctx.invalid_char(c, shift=-1)
    None => raise ParseError("invalid eof")
  }
}

///|
fn ParseContext::lex_after_object_value(
  ctx : ParseContext,
) -> Token raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some('}') => RBrace
    Some(',') => Comma
    Some(c) => ctx.invalid_char(c, shift=-1)
    None => raise ParseError("invalid eof")
  }
}

///|
/// In the context of `{`, try to lex token `}` or a property name,
/// otherwise raise an error.
fn ParseContext::lex_property_name(
  ctx : ParseContext,
) -> Token raise ParseError {
  ctx.lex_skip_whitespace()
  match ctx.read_char() {
    Some('}') => RBrace
    Some('"') => {
      let s = ctx.lex_string()
      String(s)
    }
    Some(c) => ctx.invalid_char(c, shift=-1)
    None => raise ParseError("invalid eof")
  }
}

///|
fn ParseContext::lex_decimal_integer(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  for ;; {
    match ctx.read_char() {
      Some('.') => return ctx.lex_decimal_point(start~)
      Some('e' | 'E') => return ctx.lex_decimal_exponent(start~)
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_decimal_point(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  match ctx.read_char() {
    Some(c) =>
      if c >= '0' && c <= '9' {
        ctx.lex_decimal_fraction(start~)
      } else {
        ctx.invalid_char(c, shift=-1)
      }
    None => raise ParseError("invalid eof")
  }
}

///|
fn ParseContext::lex_decimal_fraction(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  for ;; {
    match ctx.read_char() {
      Some('e' | 'E') => return ctx.lex_decimal_exponent(start~)
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_decimal_exponent(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  match ctx.read_char() {
    Some('+') | Some('-') => return ctx.lex_decimal_exponent_sign(start~)
    Some(c) => {
      if c >= '0' && c <= '9' {
        return ctx.lex_decimal_exponent_integer(start~)
      }
      ctx.invalid_char(c, shift=-1)
    }
    None => raise ParseError("invalid eof")
  }
}

///|
fn ParseContext::lex_decimal_exponent_sign(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  match ctx.read_char() {
    Some(c) => {
      if c >= '0' && c <= '9' {
        return ctx.lex_decimal_exponent_integer(start~)
      }
      ctx.invalid_char(c, shift=-1)
    }
    None => raise ParseError("invalid eof")
  }
}

///|
fn ParseContext::lex_decimal_exponent_integer(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  for ;; {
    match ctx.read_char() {
      Some(c) => {
        if c >= '0' && c <= '9' {
          continue
        }
        ctx.offset -= 1
        return ctx.lex_number_end(start, ctx.offset)
      }
      None => return ctx.lex_number_end(start, ctx.offset)
    }
  }
}

///|
fn ParseContext::lex_zero(
  ctx : ParseContext,
  start~ : Int,
) -> Double raise ParseError {
  match ctx.read_char() {
    Some('.') => ctx.lex_decimal_point(start~)
    Some('e' | 'E') => ctx.lex_decimal_exponent(start~)
    Some(c) => {
      if c >= '0' && c <= '9' {
        ctx.invalid_char(c, shift=-1)
      }
      ctx.offset -= 1
      return ctx.lex_number_end(start, ctx.offset)
    }
    None => return ctx.lex_number_end(start, ctx.offset)
  }
}

///|
fn ParseContext::lex_number_end(
  ctx : ParseContext,
  start : Int,
  end : Int,
) -> Double raise ParseError {
  let s = ctx.buf.substring(start~, end~)
  @string.parse_double(s) catch {
    _ => raise ParseError("invalid number '\{s}' at offsets \{start}:\{end}") // InvalidNumber(offset_to_position(ctx.input, start), s)
  }
}

///|
fn ParseContext::lex_string(ctx : ParseContext) -> String raise ParseError {
  let buf = StringBuilder::new()
  let mut start = ctx.offset
  fn flush(end : Int) {
    if start > 0 && end > start {
      // buf.write_substring(ctx.input, start, end - start)
      buf.write_string(ctx.buf.substring(start~, end~))
    }
  }

  for ;; {
    match ctx.read_char() {
      Some('"') => {
        flush(ctx.offset - 1)
        break
      }
      Some('\n' | '\r') as c => ctx.invalid_char(c.unwrap(), shift=-1)
      Some('\\') => {
        flush(ctx.offset - 1)
        match ctx.read_char() {
          Some('b') => buf.write_char('\b')
          Some('f') => buf.write_char('\u{0C}')
          Some('n') => buf.write_char('\n')
          Some('r') => buf.write_char('\r')
          Some('t') => buf.write_char('\t')
          Some('"') => buf.write_char('"')
          Some('\\') => buf.write_char('\\')
          Some('/') => buf.write_char('/')
          Some('u') => {
            let c = ctx.lex_hex_digits(4)
            buf.write_char(Int::unsafe_to_char(c))
          }
          Some(c) => ctx.invalid_char(c, shift=-1)
          None => raise ParseError("invalid eof")
        }
        start = ctx.offset
      }
      Some(ch) =>
        if ch.to_int() < 32 {
          ctx.invalid_char(ch, shift=-1)
        } else {
          continue
        }
      None => raise ParseError("invalid eof")
    }
  }
  buf.to_string()
}

///|
fn ParseContext::lex_hex_digits(
  ctx : ParseContext,
  n : Int,
) -> Int raise ParseError {
  let mut r = 0
  for _ in 0..<n {
    match ctx.read_char() {
      Some(c) =>
        if c >= 'A' {
          let d = (c.to_int() & (32).lnot()) - 'A'.to_int() + 10
          if d > 15 {
            ctx.invalid_char(c, shift=-1)
          }
          r = (r << 4) | d
        } else if c >= '0' {
          let d = c.to_int() - '0'.to_int()
          if d > 9 {
            ctx.invalid_char(c, shift=-1)
          }
          r = (r << 4) | d
        } else {
          ctx.invalid_char(c, shift=-1)
        }
      None => raise ParseError("invalid eof")
    }
  }
  r
}
