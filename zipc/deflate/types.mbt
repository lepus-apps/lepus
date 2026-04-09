// Core types for deflate module

// Compression levels

///|
pub enum Level {
  None // Only non-compressed blocks
  Fast
  Default
  Best
} derive(Debug)

// Helper functions to create Level values

///|
pub fn level_none() -> Level {
  Level::None
}

///|
pub fn level_fast() -> Level {
  Level::Fast
}

///|
pub fn level_default() -> Level {
  Level::Default
}

///|
pub fn level_best() -> Level {
  Level::Best
}

// Result type for operations that can fail

///|
pub enum Result[T, E] {
  Ok(T)
  Err(E)
}

// Helper function to create Ok result

///|
pub fn[T, E] ok(value : T) -> Result[T, E] {
  Ok(value)
}

// Helper function to create Err result

///|
pub fn[T, E] err(error : E) -> Result[T, E] {
  Err(error)
}

// Helper function to unwrap Result or panic

///|
pub fn[T, E] unwrap(result : Result[T, E]) -> T {
  match result {
    Ok(value) => value
    Err(_) => abort("unwrap called on Err value")
  }
}

// Helper function to unwrap Result or return default

///|
pub fn[T, E] unwrap_or(result : Result[T, E], default : T) -> T {
  match result {
    Ok(value) => value
    Err(_) => default
  }
}
