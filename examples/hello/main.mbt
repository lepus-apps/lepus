///|
fn main {
  @lepus.Window::new(
    title="Hello Lepus",
    html=(
      #|<!doctype html>
      #|<html><body><h1>Hello Lepus</h1></body></html>,
    ),
  ).run()
}
