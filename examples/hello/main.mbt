///|
async fn main {
  @lepus.Window::new(
    title="Hello Lepus",
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><body><h1>Hello Lepus</h1></body></html>,
      ),
    ),
  ).run()
}
