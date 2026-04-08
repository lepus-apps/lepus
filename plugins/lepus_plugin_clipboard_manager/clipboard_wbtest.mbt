///|
test "empty clipboard text decodes to None" {
  assert_eq(decode_optional_text(@utf8.encode("")), None)
}

///|
test "utf8 clipboard text decodes to Some" {
  assert_eq(decode_optional_text(@utf8.encode("hello")), Some("hello"))
  assert_eq(
    decode_optional_text(@utf8.encode("hello world")),
    Some("hello world"),
  )
}

///|
test "error message falls back when ffi message is empty" {
  assert_eq(decode_error_message(@utf8.encode(""), "fallback"), "fallback")
  assert_eq(
    decode_error_message(@utf8.encode("clipboard unavailable"), "fallback"),
    "clipboard unavailable",
  )
}

///|
test "ensure_supported_result covers both outcomes" {
  ignore(ensure_supported_result(true))
  let message = try {
    ignore(ensure_supported_result(false))
    ""
  } catch {
    ClipboardError(message) => message
  }
  assert_eq(message, unsupported_error_message())
}

///|
test "read_text_result handles unsupported clipboard" {
  let message = try {
    ignore(
      read_text_result(
        false,
        @utf8.encode("ignored"),
        0,
        @utf8.encode("ignored"),
      ),
    )
    ""
  } catch {
    ClipboardError(message) => message
  }
  assert_eq(message, unsupported_error_message())
}

///|
test "read_text_result handles success cases" {
  assert_eq(read_text_result(true, @utf8.encode(""), 0, @utf8.encode("")), None)
  assert_eq(
    read_text_result(true, @utf8.encode("hello"), 0, @utf8.encode("")),
    Some("hello"),
  )
}

///|
test "read_text_result handles explicit and fallback errors" {
  let explicit = try {
    ignore(
      read_text_result(
        true,
        @utf8.encode("ignored"),
        1,
        @utf8.encode("backend failed"),
      ),
    )
    ""
  } catch {
    ClipboardError(message) => message
  }
  assert_eq(explicit, "backend failed")

  let fallback = try {
    ignore(read_text_result(true, @utf8.encode("ignored"), 1, @utf8.encode("")))
    ""
  } catch {
    ClipboardError(message) => message
  }
  assert_eq(fallback, "clipboard read failed")
}

///|
test "write_text_result handles unsupported clipboard" {
  let message = try {
    write_text_result(false, 1, @utf8.encode("ignored"))
    ""
  } catch {
    ClipboardError(message) => message
  }
  assert_eq(message, unsupported_error_message())
}

///|
test "write_text_result handles success and error cases" {
  write_text_result(true, 0, @utf8.encode(""))

  let explicit = try {
    write_text_result(true, 1, @utf8.encode("permission denied"))
    ""
  } catch {
    ClipboardError(message) => message
  }
  assert_eq(explicit, "permission denied")

  let fallback = try {
    write_text_result(true, 1, @utf8.encode(""))
    ""
  } catch {
    ClipboardError(message) => message
  }
  assert_eq(fallback, "clipboard write failed")
}
