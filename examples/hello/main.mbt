///|
async fn main {
  @lepus.Window(
    title="Hello Lepus",
    source=@lepus.Source::html(
      (
        #|<!doctype html>
        #|<html><body><h1>Hello Lepus</h1></body></html>
      ),
    ),
  ).run()
}
