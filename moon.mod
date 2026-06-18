name = "lepus-apps/lepus"

version = "0.1.8"

import {
  "lepus-apps/webview@0.1.15",
  "moonbitlang/x@0.4.45",
  "moonbitlang/async@0.19.4",
  "moonbitlang/parser@0.3.4",
}

readme = "README.mbt.md"

repository = "https://github.com/lepus-apps/lepus"

license = "Apache-2.0"

keywords = [ "webview", "desktop", "app", "framework" ]

description = "A modern desktop application framework based on web technologies."

preferred_target = "native"

options(
  source: ".",
)
