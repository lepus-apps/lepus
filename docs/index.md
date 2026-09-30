---
layout: home

title: Lepus

titleTemplate: Native desktop applications with MoonBit

hero:
  name: Lepus
  text: Native desktop applications with MoonBit
  tagline: WebView windows, typed plugins, multi-window orchestration, and a practical project CLI.
  image:
    src: /logo.svg
    alt: Lepus
  actions:
    - theme: brand
      text: Get Started
      link: /getting-started
    - theme: alt
      text: Core API
      link: /core-api
    - theme: alt
      text: View on GitHub
      link: https://github.com/lepus-apps/lepus

features:
  - icon: ◈
    title: Native windows
    details: Build single-window and multi-window applications backed by the platform WebView runtime.
  - icon: ↔
    title: Typed bridge
    details: Expose MoonBit handlers as promise-based JavaScript commands with JSON payloads and replies.
  - icon: ◫
    title: Official plugins
    details: Add filesystem, dialogs, HTTP, process, storage, WebSocket, and other capabilities when needed.
  - icon: ⧉
    title: Flexible sources
    details: Load inline HTML, local directories, remote URLs, or in-memory ZIP assets.
  - icon: ⌘
    title: Multi-window runtime
    details: Choose a shared single-process event loop or isolated process-per-window execution.
  - icon: ›_
    title: Project CLI
    details: Diagnose, develop, build, and package Lepus applications from one command surface.
---

## Quick start

```moonbit
///|
async fn main {
  @lepus.Window(
    title="Hello Lepus",
    width=800,
    height=600,
    source=@lepus.Source::html("<h1>Hello from MoonBit</h1>"),
  ).run()
}
```

```sh
moon run --target native main.mbt
```

Continue with the [Getting Started guide](/getting-started), or browse the
[Core API](/core-api) and [Plugin Matrix](/plugin-matrix).
