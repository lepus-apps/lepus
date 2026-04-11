///|
test "opener unsupported decoder fallback" {
  inspect(
    decode_error_message(@utf8.encode(""), "fallback"),
    content="fallback",
  )
}

///|
test "open_reply validates empty target" {
  let reply = open_reply("")
  inspect(reply.ok, content="false")
}
