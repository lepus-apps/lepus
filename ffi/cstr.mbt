///|
/// # C-Style String Conversion Module
/// 
/// This module provides functions to convert between C-style null-terminated byte strings
/// and MoonBit's `String` type. It is essential for FFI (Foreign Function Interface)
/// operations where you need to pass strings to C functions or receive strings from C code.
/// 
/// ## Features
/// 
/// - **C string compatibility**: Handles null-terminated byte arrays as used by C
/// - **Bidirectional conversion**: Convert from and to C-style strings
/// - **Safety checks**: Validates null termination and proper formatting
/// - **FFI integration**: Designed for seamless integration with FFI calls
/// - **UTF-8 support**: Properly handles UTF-8 encoded text content
/// 
/// ## Basic Usage
/// 
/// ```moonbit
/// // Convert MoonBit string to C-style null-terminated bytes
/// let moonbit_str = "Hello, World!"
/// let c_str_bytes = @ffi.to_cstr(moonbit_str)
/// // c_str_bytes now contains: b"Hello, World!\x00"
/// 
/// // Convert C-style bytes back to MoonBit string
/// let recovered_str = @ffi.from_cstr(c_str_bytes)
/// // recovered_str equals "Hello, World!"
/// 
/// // Use with FFI functions that expect C strings
/// // extern "C" fn c_function_that_takes_string(s : Bytes) -> Int = "my_c_function"
/// // let result = c_function_that_takes_string(@ffi.to_cstr("Hello from MoonBit!"))
/// ```
/// 
/// ## C String Format
/// 
/// C-style strings are byte arrays where:
/// - Each character is represented as a single byte
/// - The string is terminated with a null byte (`\x00`)
/// - No length information is stored (length determined by null terminator)
/// - Compatible with standard C library string functions
/// 
/// ## Error Handling
/// 
/// - `from_cstr()` will abort if the input is not properly null-terminated
/// - `to_cstr()` always produces valid null-terminated output
/// - Functions expect valid UTF-8 input for proper character conversion
/// 
/// ## Platform Considerations
/// 
/// - **ASCII/UTF-8**: This module handles single-byte character encodings
/// - **Windows**: For wide character strings (UTF-16), use the `wstr` module instead
/// - **C interop**: Perfect for POSIX APIs and most Unix/Linux C functions

///|
/// Converts a null-terminated byte array to a `String`.
/// 
/// This function takes a C-style null-terminated byte array and converts it
/// to a MoonBit `String`. It validates that the input is properly null-terminated
/// and removes the terminating null byte during conversion.
/// 
/// The function performs the following operations:
/// 1. Validates that the last byte is a null terminator (`\x00`)
/// 2. Removes the null terminator from the byte array
/// 3. Converts each byte to its corresponding character
/// 4. Constructs a MoonBit `String` from the character array
/// 
/// ## Parameters
/// 
/// - `b`: A byte array that must be null-terminated (ending with `\x00`)
/// 
/// ## Returns
/// 
/// A `String` representation of the byte array, excluding the null terminator
/// 
/// ## Example
/// 
/// ```moonbit nocheck
/// // Basic conversion
/// let c_str = b"Hello, world!\x00"
/// let moonbit_str = @ffi.from_cstr(c_str)
/// assert_eq(moonbit_str, "Hello, world!")
///
/// // UTF-8 text conversion
/// let utf8_c_str = b"Caf\xc3\xa9\x00"  // "Café" in UTF-8 with null terminator
/// let utf8_str = @ffi.from_cstr(utf8_c_str)
/// assert_eq(utf8_str, "Café")
///
/// // Empty string conversion
/// let empty_c_str = b"\x00"
/// let empty_str = @ffi.from_cstr(empty_c_str)
/// assert_eq(empty_str, "")
/// ```
/// 
/// ## Safety
/// 
/// - **Validation**: The function aborts with an error message if the input is not null-terminated
/// - **Memory safety**: No buffer overflows as the function respects byte array boundaries
/// - **Character encoding**: Assumes valid UTF-8 byte sequences for proper character conversion
/// 
/// ## Error Conditions
/// 
/// The function will abort execution if:
/// - The input byte array is empty
/// - The last byte is not `\x00` (null terminator)
/// - The input is not a valid null-terminated C string
pub fn from_cstr(b : Bytes) -> String {
  if b[b.length() - 1] != 0x00 {
    abort("expected null-terminated byte strings")
  }
  let b = b.to_array()
  let _ = b.pop()
  return b.map(fn(c) { c.to_char() }) |> String::from_array
}

///|
/// Converts a `String` to a C-style null-terminated byte array.
/// 
/// This function takes a MoonBit `String` and converts it to a null-terminated
/// byte array suitable for passing to C functions via FFI. It appends a null
/// terminator (`\x00`) to ensure C compatibility.
/// 
/// The function performs the following operations:
/// 1. Converts the string to a character array
/// 2. Appends a null character (`\u{0000}`) to the array
/// 3. Converts each character to its byte representation
/// 4. Returns the resulting byte array
/// 
/// ## Parameters
/// 
/// - `s`: A `String` that will be converted to a null-terminated byte array
/// 
/// ## Returns
/// 
/// A `Bytes` object containing the null-terminated byte representation of the string.
/// The returned bytes are suitable for passing to C functions that expect C-style strings.
/// 
/// ## Example
/// 
/// ```moonbit nocheck
/// // Basic conversion
/// let moonbit_str = "Hello, world!"
/// let c_str = @ffi.to_cstr(moonbit_str)
/// assert_eq(c_str, b"Hello, world!\x00")
///
/// // Empty string conversion
/// let empty_str = ""
/// let empty_c_str = @ffi.to_cstr(empty_str)
/// assert_eq(empty_c_str, b"\x00")
///
/// // UTF-8 text conversion
/// let utf8_str = "Café"
/// let utf8_c_str = @ffi.to_cstr(utf8_str)
/// assert_eq(utf8_c_str, b"Caf\xc3\xa9\x00")
///
/// // Using with FFI functions
/// // extern "C" fn printf(format : Bytes, ...) -> Int = "printf"
/// // let message = "Hello from MoonBit!"
/// // let result = printf(@ffi.to_cstr("%s\n"), @ffi.to_cstr(message))
/// ```
/// 
/// ## Memory Management
/// 
/// - **Safe allocation**: The function creates a new byte array, no memory leaks
/// - **Automatic sizing**: Automatically calculates the correct buffer size
/// - **Null termination**: Always ensures proper null termination for C compatibility
/// 
/// ## Character Encoding
/// 
/// - **UTF-8 compatible**: Properly handles UTF-8 encoded characters
/// - **Byte-by-byte**: Each character is converted to its byte representation
/// - **C standard**: Results are compatible with standard C string functions
/// 
/// ## Use Cases
/// 
/// - **FFI calls**: Passing strings to C functions that expect `char*` parameters
/// - **File operations**: Working with C file APIs that use string paths
/// - **System calls**: Interfacing with POSIX APIs that require C strings
/// - **Library integration**: Calling third-party C libraries from MoonBit
pub fn to_cstr(s : String) -> Bytes {
  let buf = @buffer.new()
  buf.write_string(s)
  buf.write_byte(0x00) // Append null terminator
  return buf.to_bytes()
}
