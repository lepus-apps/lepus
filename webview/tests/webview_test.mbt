///|
test {
  let container = box <| [
    text <| "Hello world",
    text <| "Hello world",
  ]
  inspect(
    container.render(),
    content=(
      #|Hello world
      #|Hello world
    ),
  )
}

///|
trait Component {
  fn render(Self) -> String
}

///|
struct Box {
  children : Array[&Component]
}

///|
impl Component for Box with fn render(self) {
  self.children.map(c => c.render()).join("\n")
}

///|
impl Component for Text with fn render(self) {
  self.text
}

///|
struct Text {
  text : String
}

///|
fn text(text : String) -> Text {
  { text, }
}

///|
fn box(children : Array[&Component]) -> Box {
  { children, }
}
