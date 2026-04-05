///|
/// # Windows Wide String (UTF-16) Conversion Module
/// 
/// This module provides functions for working with Windows wide strings (UTF-16 encoded)
/// which are commonly used in Windows API functions. Windows represents Unicode characters
/// using UTF-16 encoding, where each character is encoded as a 16-bit value.
/// 
/// UTF-16 characters are called **wide** characters, to distinguish them from
/// 8-bit ANSI characters used in traditional C strings.
/// 
/// ## Features
/// 
/// - **UTF-16 support**: Full Unicode support via UTF-16 encoding
/// - **Windows API compatibility**: Designed for Windows API functions ending in 'W'
/// - **Null termination**: Proper null termination for C compatibility
/// - **Lossy conversion**: Safe conversion that handles invalid UTF-16 sequences
/// - **Bidirectional**: Convert from and to wide strings
/// 
/// ## Basic Usage
/// 
/// ```moonbit
/// // Convert MoonBit string to Windows wide string (UTF-16)
/// let moonbit_str = "Hello, 世界!"
/// let wide_str = @ffi.to_wstr(moonbit_str)
/// // wide_str contains UTF-16 bytes with null termination
/// 
/// // Convert wide string back to MoonBit string
/// let recovered_str = @ffi.from_wstr_lossy(wide_str)
/// // recovered_str equals "Hello, 世界!"
/// 
/// // Use with Windows API functions
/// // extern "C" fn MessageBoxW(hWnd : Int, lpText : Bytes, lpCaption : Bytes, uType : Int) -> Int = "MessageBoxW"
/// // let result = MessageBoxW(0, 
/// //   @ffi.to_wstr("Hello from MoonBit!"), 
/// //   @ffi.to_wstr("Title"), 
/// //   0)
/// ```
/// 
/// ## UTF-16 Encoding Details
/// 
/// UTF-16 encoding characteristics:
/// - **Basic characters**: Most characters encoded as single 16-bit units
/// - **Surrogate pairs**: Characters outside BMP use two 16-bit units
/// - **Byte order**: Uses system byte order (little-endian on x86/x64)
/// - **Null termination**: Terminated with two zero bytes (`\x00\x00`)
/// 
/// ## Windows API Integration
/// 
/// This module is specifically designed for Windows APIs that use wide strings:
/// - Functions ending in 'W' (wide) rather than 'A' (ANSI)
/// - Registry functions, file operations, UI functions
/// - Modern Windows APIs that require Unicode support
/// 
/// ## Error Handling
/// 
/// - **Lossy conversion**: `from_wstr_lossy()` handles invalid UTF-16 gracefully
/// - **Validation**: Functions validate proper null termination
/// - **Encoding safety**: Uses MoonBit's built-in UTF-16 encoder/decoder
/// 
/// ## Platform Considerations
/// 
/// - **Windows specific**: Primarily useful for Windows development
/// - **Cross-platform**: Can be used on other platforms for UTF-16 data
/// - **Performance**: Efficient conversion using native encoding libraries

///|
/// Converts a null-terminated UTF-16 byte array to a `String`.
/// 
/// This function handles UTF-16 encoded wide strings commonly used on Windows.
/// It expects the byte array to be null-terminated (ending with two zero bytes)
/// and uses lossy conversion to handle any invalid UTF-16 sequences gracefully.
/// 
/// The function performs the following operations:
/// 1. Validates that the input is properly null-terminated (last two bytes are zero)
/// 2. Removes the null termination bytes
/// 3. Uses the UTF-16 decoder to convert bytes to a string
/// 4. Applies lossy conversion to handle invalid sequences
/// 
/// ## Parameters
/// 
/// - `b`: A byte array containing UTF-16 encoded data, expected to be null-terminated
///   with two zero bytes (`\x00\x00`)
/// 
/// ## Returns
/// 
/// A `String` representation of the UTF-16 data, excluding the null terminator.
/// Invalid UTF-16 sequences are replaced with the Unicode replacement character (�).
/// 
/// ## Example
/// 
/// ```moonbit nocheck
/// // Basic ASCII conversion
/// let wide_hello = b"\x48\x00\x65\x00\x6c\x00\x6c\x00\x6f\x00\x00\x00"
/// let str_hello = @ffi.from_wstr_lossy(wide_hello)
/// assert_eq(str_hello, "Hello")
///
/// // Unicode characters (Chinese text)
/// let wide_chinese = b"\x16\x4e\x96\x75\x00\x00"  // "世界" in UTF-16LE
/// let str_chinese = @ffi.from_wstr_lossy(wide_chinese)
/// assert_eq(str_chinese, "世界")
///
/// // Empty string
/// let empty_wide = b"\x00\x00"
/// let empty_str = @ffi.from_wstr_lossy(empty_wide)
/// assert_eq(empty_str, "")
///
/// // Mixed content
/// let mixed = b"\x48\x00\x65\x00\x6c\x00\x6c\x00\x6f\x00\x2c\x00\x20\x00\x16\x4e\x96\x75\x21\x00\x00\x00"
/// let mixed_str = @ffi.from_wstr_lossy(mixed)
/// assert_eq(mixed_str, "Hello, 世界!")
/// ```
/// 
/// ## Safety and Error Handling
/// 
/// - **Null termination check**: Aborts if the input is not properly null-terminated
/// - **Lossy conversion**: Invalid UTF-16 sequences are replaced rather than causing errors
/// - **Memory safety**: Respects byte array boundaries and validates input length
/// - **Graceful degradation**: Continues processing even with some invalid data
/// 
/// ## UTF-16 Specifics
/// 
/// - **Byte order**: Assumes system byte order (little-endian on Windows x86/x64)
/// - **Surrogate pairs**: Properly handles characters requiring surrogate pairs
/// - **BOM handling**: Does not expect or process Byte Order Mark (BOM)
/// - **Alignment**: Input should be properly aligned for 16-bit values
/// 
/// ## Error Conditions
/// 
/// The function will abort execution if:
/// - The input byte array has fewer than 2 bytes
/// - The last two bytes are not both `\x00` (proper null termination)
/// - The input is not a valid null-terminated wide string
pub fn from_wstr_lossy(b : Bytes) -> String {
  if b.length() < 2 || b[b.length() - 2] != 0x00 || b[b.length() - 1] != 0x00 {
    abort("expected null-terminated wide strings")
  }
  return @utf16.decode_lossy(b[0:b.length() - 2])
}

///|
/// Converts a `String` to a null-terminated UTF-16 byte array.
/// 
/// This function converts a MoonBit string to UTF-16 encoding with null termination,
/// which is the format commonly used for Windows wide string APIs. The resulting
/// byte array can be passed directly to Windows API functions that expect wide strings.
/// 
/// The function performs the following operations:
/// 1. Appends a null terminator to the input string
/// 2. Uses the UTF-16 encoder to convert the string to bytes
/// 3. Returns the encoded byte array with proper null termination
/// 
/// ## Parameters
/// 
/// - `s`: A `String` that will be converted to a null-terminated UTF-16 byte array
/// 
/// ## Returns
/// 
/// A `Bytes` object containing the UTF-16 encoded representation with null termination.
/// The result is suitable for passing to Windows API functions that expect wide strings.
/// 
/// ## Example
/// 
/// ```moonbit nocheck
/// // Basic ASCII conversion
/// let hello_str = "Hello"
/// let hello_wide = @ffi.to_wstr(hello_str)
/// assert_eq(hello_wide, b"\x48\x00\x65\x00\x6c\x00\x6c\x00\x6f\x00\x00\x00")
///
/// // Unicode characters (Chinese text)
/// let chinese_str = "世界"
/// let chinese_wide = @ffi.to_wstr(chinese_str)
/// assert_eq(chinese_wide, b"\x16\x4e\x96\x75\x00\x00")
///
/// // Empty string
/// let empty_str = ""
/// let empty_wide = @ffi.to_wstr(empty_str)
/// assert_eq(empty_wide, b"\x00\x00")
///
/// // Mixed content with emojis
/// let mixed_str = "Hello, 世界! 🌍"
/// let mixed_wide = @ffi.to_wstr(mixed_str)
/// assert_eq(mixed_wide, b"\x48\x00\x65\x00\x6c\x00\x6c\x00\x6f\x00\x2c\x00\x20\x00\x16\x4e\x96\x75\x21\x00\x20\xd8\x3d\xde\x0d\x00\x00")
///
/// // Using with Windows API
/// // extern "C" fn CreateFileW(
/// //   lpFileName : Bytes,
/// //   dwDesiredAccess : Int,
/// //   dwShareMode : Int,
/// //   lpSecurityAttributes : Int64,
/// //   dwCreationDisposition : Int,
/// //   dwFlagsAndAttributes : Int,
/// //   hTemplateFile : Int64
/// // ) -> Int64 = "CreateFileW"
/// // 
/// // let file_handle = CreateFileW(
/// //   @ffi.to_wstr("C:\\path\\to\\file.txt"),
/// //   0x80000000,  // GENERIC_READ
/// //   1,           // FILE_SHARE_READ
/// //   0,           // No security attributes
/// //   3,           // OPEN_EXISTING
/// //   0x80,        // FILE_ATTRIBUTE_NORMAL
/// //   0            // No template file
/// // )
/// ```
/// 
/// ## UTF-16 Encoding Details
/// 
/// - **Character representation**: Each character encoded as one or two 16-bit units
/// - **Byte order**: Uses system byte order (little-endian on Windows x86/x64)
/// - **Surrogate pairs**: Automatically handles characters outside the Basic Multilingual Plane
/// - **Null termination**: Always appends two zero bytes for C API compatibility
/// 
/// ## Memory and Performance
/// 
/// - **Memory allocation**: Creates a new byte array with proper sizing
/// - **Encoding efficiency**: Uses optimized UTF-16 encoding implementation
/// - **Size calculation**: Automatically determines correct buffer size
/// - **No leaks**: Memory management handled by MoonBit runtime
/// 
/// ## Use Cases
/// 
/// - **Windows API calls**: Perfect for functions ending in 'W' (wide character versions)
/// - **File operations**: Windows file paths and names
/// - **Registry operations**: Windows registry keys and values
/// - **UI operations**: Window titles, menu items, dialog text
/// - **COM interfaces**: Component Object Model string parameters
/// 
/// ## Character Support
/// 
/// - **ASCII**: All ASCII characters (0-127) encoded efficiently
/// - **Latin scripts**: Full support for European languages
/// - **CJK characters**: Chinese, Japanese, Korean character support
/// - **Emojis**: Modern Unicode emojis and symbols
/// - **Mathematical symbols**: Unicode mathematical and technical symbols
pub fn to_wstr(s : String) -> Bytes {
  return @utf16.encode(s + "\u{0000}")
}
