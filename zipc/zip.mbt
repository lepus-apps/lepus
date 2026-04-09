// Simplified ZIP module - self-contained implementation

// Basic ZIP types

///|
pub enum Compression {
  Stored
  Deflate
  Other(Int)
}

///|
pub type Fpath = String

///|
pub type Mode = Int

///|
pub type Ptime = Int

///|
pub struct File {
  compression : Compression
  start : Int
  compressed_size : Int
  compressed_bytes : Bytes
  decompressed_size : Int
  decompressed_crc32 : Int64 // Using Int64 directly instead of @deflate.Crc32
  version_made_by : Int
  version_needed_to_extract : Int
  gp_flags : Int
}

///|
pub enum MemberKind {
  Dir
  File(File)
}

///|
pub struct Member {
  path : Fpath
  mode : Mode
  mtime : Ptime
  kind : MemberKind
}

///|
pub struct Archive {
  members : Map[String, Member]
}

// Constants

///|
pub let dos_epoch : Ptime = 315532800 // 1980-01-01 00:00:00 UTC

///|
pub let max_file_size : Int = 2147483647 // Use max int instead of 4GB

///|
pub let max_members : Int = 65535 // ZIP32 limit

///|
pub let max_path_length : Int = 65535

// Archive operations

///|
pub fn Archive::new() -> Archive {
  { members: Map::new() }
}

///|
pub fn Archive::is_empty(self : Archive) -> Bool {
  self.members.length() == 0
}

///|
pub fn Archive::member_count(self : Archive) -> Int {
  self.members.length()
}

///|
pub fn Archive::add(self : Archive, mem : Member) -> Archive {
  let new_members = self.members
  new_members[mem.path] = mem
  { members: new_members }
}

///|
pub fn Archive::find(self : Archive, path : Fpath) -> Member? {
  self.members.get(path)
}

///|
pub fn Archive::mem(self : Archive, path : Fpath) -> Bool {
  self.members.contains(path)
}

///|
pub fn Archive::remove(self : Archive, path : Fpath) -> Archive {
  self.members.remove(path)
  self
}

// File operations

///|
pub fn File::from_string(s : String) -> File raise {
  let data = @utf8.encode(s)
  let len = data.length()
  if len > max_file_size {
    fail(
      "File size exceeds maximum allowed (" +
      max_file_size.to_string() +
      " bytes)",
    )
  }

  // Calculate actual CRC-32 checksum
  let crc = @crc32.bytes(data)
  {
    compression: Compression::Stored,
    start: 0,
    compressed_size: len,
    compressed_bytes: data,
    decompressed_size: len,
    decompressed_crc32: crc.0,
    version_made_by: 0x314, // UNIX, PKZIP 2.0
    version_needed_to_extract: 20, // PKZIP 2.0
    gp_flags: 0x800, // UTF-8 filename
  }
}

// Create stored file from bytes (more efficient for binary data)

///|
pub fn File::from_bytes(data : Bytes) -> File raise {
  let len = data.length()
  if len > max_file_size {
    fail(
      "File size exceeds maximum allowed (" +
      max_file_size.to_string() +
      " bytes)",
    )
  }

  let crc = @crc32.bytes(data)
  {
    compression: Compression::Stored,
    start: 0,
    compressed_size: len,
    compressed_bytes: data,
    decompressed_size: len,
    decompressed_crc32: crc.0,
    version_made_by: 0x314, // UNIX, PKZIP 2.0
    version_needed_to_extract: 20, // PKZIP 2.0
    gp_flags: 0x800, // UTF-8 filename
  }
}

// Create deflate-compressed file

///|
pub fn deflate_of_binary_string(
  s : String,
  level : @deflate.Level,
) -> @deflate.Result[File, String] {
  let data = @utf8.encode(s)
  let len = data.length()
  if len > max_file_size {
    return @deflate.err(
      "File size exceeds maximum allowed (" +
      max_file_size.to_string() +
      " bytes)",
    )
  }

  // Compress using deflate
  let compressed_data = @deflate.deflate_of_bytes(data, level)
  let crc = @crc32.bytes(data)
  @deflate.ok({
    compression: Compression::Deflate,
    start: 0,
    compressed_size: compressed_data.length(),
    compressed_bytes: compressed_data,
    decompressed_size: len,
    decompressed_crc32: crc.0,
    version_made_by: 0x314, // UNIX, ZIP 2.0
    version_needed_to_extract: 20, // ZIP 2.0
    gp_flags: 0x800, // UTF-8 filename
  })
}

// Create deflate-compressed file from bytes (more efficient for binary data)

///|
pub fn deflate_of_bytes(
  data : Bytes,
  level : @deflate.Level,
) -> @deflate.Result[File, String] {
  let len = data.length()
  if len > max_file_size {
    return @deflate.err(
      "File size exceeds maximum allowed (" +
      max_file_size.to_string() +
      " bytes)",
    )
  }

  // Compress using deflate directly on bytes (more efficient)
  let compressed_data = @deflate.deflate_of_bytes(data, level)
  let crc = @crc32.bytes(data)
  @deflate.ok({
    compression: Compression::Deflate,
    start: 0,
    compressed_size: compressed_data.length(),
    compressed_bytes: compressed_data,
    decompressed_size: len,
    decompressed_crc32: crc.0,
    version_made_by: 0x314, // UNIX, ZIP 2.0
    version_needed_to_extract: 20, // ZIP 2.0
    gp_flags: 0x800, // UTF-8 filename
  })
}

///|
pub fn File::compression(self : File) -> Compression {
  self.compression
}

///|
pub fn File::compressed_size(self : File) -> Int {
  self.compressed_size
}

///|
pub fn File::decompressed_size(self : File) -> Int {
  self.decompressed_size
}

///|
pub fn File::compressed_bytes(self : File) -> Bytes {
  self.compressed_bytes
}

///|
pub fn File::can_extract(file : File) -> Bool {
  match file.compression {
    Compression::Stored => true
    Compression::Deflate => true // Would need actual deflate implementation
    _ => false
  }
}

// Extract file content as bytes (more efficient for binary data)

///|
pub fn file_to_bytes(file : File) -> Bytes raise {
  if !file.can_extract() {
    fail("Unsupported compression format")
  }
  match file.compression {
    Compression::Stored => {
      let data_view = file.compressed_bytes[file.start:file.start +
        file.compressed_size]
      // Convert view back to bytes
      data_view.to_bytes()
    }
    Compression::Deflate =>
      // Use bytes-based decompression for better performance
      @deflate.deflate_decompress_bytes(
        file.compressed_bytes,
        file.decompressed_size,
      )
    _ => fail("Unsupported compression format")
  }
}

// Member operations

///|
pub fn member_make(
  path : Fpath,
  kind : MemberKind,
) -> @deflate.Result[Member, String] {
  if path.length() > max_path_length {
    return @deflate.err(
      "Path length exceeds maximum allowed (" +
      max_path_length.to_string() +
      " bytes)",
    )
  }
  let sanitized_path = path.replace(old="\\", new="/")
  let final_path = match kind {
    MemberKind::Dir =>
      if sanitized_path.is_empty() {
        "./"
      } else if sanitized_path.strip_suffix("/") is Some(_) {
        sanitized_path
      } else {
        sanitized_path + "/"
      }
    MemberKind::File(_) => sanitized_path
  }
  let default_mode = match kind {
    MemberKind::Dir => 0o755
    MemberKind::File(_) => 0o644
  }
  @deflate.ok({
    path: final_path,
    mtime: dos_epoch, // Default mtime
    mode: default_mode,
    kind,
  })
}

///|
pub fn member_path(mem : Member) -> Fpath {
  mem.path
}

///|
pub fn member_mode(mem : Member) -> Mode {
  mem.mode
}

///|
pub fn member_mtime(mem : Member) -> Ptime {
  mem.mtime
}

///|
pub fn member_kind(mem : Member) -> MemberKind {
  mem.kind
}

// Archive encoding/decoding

///|
pub fn to_binary_string(
  archive : Archive,
) -> @deflate.Result[StringView, String] {
  let count = archive.member_count()
  if count > max_members {
    return @deflate.err(
      "Archive has too many members (\{count}), max is \{max_members}",
    )
  }
  if archive.is_empty() {
    // Empty ZIP file: just EOCD record
    let eocd = "PK\u{05}\u{06}" + String::make(18, '\u{00}')
    @deflate.ok(eocd)
  } else {
    // Build complete ZIP file
    build_zip_file(archive)
  }
}

// Convert archive to bytes (more efficient for binary data)

///|
pub fn Archive::to_bytes(self : Archive) -> @deflate.Result[Bytes, String] {
  // Use the existing string-based implementation and convert to bytes
  // In a full implementation, this would work directly with bytes throughout
  match to_binary_string(self) {
    @deflate.Ok(zip_string) => @deflate.ok(@utf8.encode(zip_string))
    @deflate.Err(error) => @deflate.err(error)
  }
}

// Build a complete ZIP file with local headers, central directory, and EOCD

///|
fn build_zip_file(archive : Archive) -> @deflate.Result[StringView, String] {
  let mut zip_data : StringView = ""
  let mut central_directory = ""
  let local_header_offsets : Array[Int] = []
  let member_list : Array[Member] = []

  // Collect all members
  archive.members.each(fn(_, mem) { member_list.push(mem) })

  // Write local file headers and data
  for mem in member_list {
    let local_header_offset = zip_data.length()
    local_header_offsets.push(local_header_offset)
    match write_local_file_header(mem) {
      @deflate.Ok(local_header_data) => zip_data = zip_data + local_header_data
      @deflate.Err(error) =>
        return @deflate.err("Failed to write local header: " + error)
    }
  }

  // Write central directory
  let central_directory_offset = zip_data.length()
  for i = 0; i < member_list.length(); i = i + 1 {
    let mem = member_list[i]
    let local_offset = local_header_offsets[i]
    match write_central_directory_entry(mem, local_offset) {
      @deflate.Ok(cd_entry) => central_directory = central_directory + cd_entry
      @deflate.Err(error) =>
        return @deflate.err("Failed to write central directory entry: " + error)
    }
  }

  // Write end of central directory record
  let eocd = write_eocd_record(
    member_list.length(),
    central_directory.length(),
    central_directory_offset,
  )
  let complete_zip = zip_data + central_directory + eocd
  @deflate.ok(complete_zip)
}

// Write local file header

///|
fn write_local_file_header(mem : Member) -> @deflate.Result[StringView, String] {
  let path = mem.path
  let path_bytes = path // Assuming UTF-8 encoding
  match mem.kind {
    MemberKind::Dir => {
      // Directory entry
      let (dos_time, dos_date) = unix_to_dos_datetime(mem.mtime)
      let header = write_u32_le(local_file_header_signature) + // Signature
        write_u16_le(20) + // Version needed
        write_u16_le(0x800) + // GP flags (UTF-8)
        write_u16_le(0) + // Compression method (stored)
        write_u16_le(dos_time) + // Last mod time
        write_u16_le(dos_date) + // Last mod date
        write_u32_le(0) + // CRC-32
        write_u32_le(0) + // Compressed size
        write_u32_le(0) + // Uncompressed size
        write_u16_le(path_bytes.length()) + // Filename length
        write_u16_le(0) // Extra field length
      @deflate.ok(header + path_bytes)
    }
    MemberKind::File(file) => {
      // File entry
      let compression_method = match file.compression {
        Compression::Stored => 0
        Compression::Deflate => 8
        Compression::Other(comp_method) => comp_method
      }
      let (dos_time, dos_date) = unix_to_dos_datetime(mem.mtime)
      let header : StringView = write_u32_le(local_file_header_signature) + // Signature
        write_u16_le(file.version_needed_to_extract) + // Version needed
        write_u16_le(file.gp_flags) + // GP flags
        write_u16_le(compression_method) + // Compression method
        write_u16_le(dos_time) + // Last mod time
        write_u16_le(dos_date) + // Last mod date
        write_u32_le(file.decompressed_crc32.to_int()) + // CRC-32
        write_u32_le(file.compressed_size) + // Compressed size
        write_u32_le(file.decompressed_size) + // Uncompressed size
        write_u16_le(path_bytes.length()) + // Filename length
        write_u16_le(0) // Extra field length
      let payload = @utf8.decode_lossy(file.compressed_bytes)
      @deflate.ok(header + path_bytes + payload)
    }
  }
}

// Write central directory entry

///|
fn write_central_directory_entry(
  mem : Member,
  local_header_offset : Int,
) -> @deflate.Result[String, String] {
  let path = mem.path
  let path_bytes = path
  match mem.kind {
    MemberKind::Dir => {
      let (dos_time, dos_date) = unix_to_dos_datetime(mem.mtime)
      let entry = write_u32_le(central_directory_signature) + // Signature
        write_u16_le(0x314) + // Version made by (Unix, ZIP 2.0)
        write_u16_le(20) + // Version needed
        write_u16_le(0x800) + // GP flags (UTF-8)
        write_u16_le(0) + // Compression method
        write_u16_le(dos_time) + // Last mod time
        write_u16_le(dos_date) + // Last mod date
        write_u32_le(0) + // CRC-32
        write_u32_le(0) + // Compressed size
        write_u32_le(0) + // Uncompressed size
        write_u16_le(path_bytes.length()) + // Filename length
        write_u16_le(0) + // Extra field length
        write_u16_le(0) + // File comment length
        write_u16_le(0) + // Disk number start
        write_u16_le(0) + // Internal file attrs
        write_u32_le((mem.mode << 16) | 0x10) + // External file attrs (directory)
        write_u32_le(local_header_offset) // Local header offset
      @deflate.ok(entry + path_bytes)
    }
    MemberKind::File(file) => {
      let compression_method = match file.compression {
        Compression::Stored => 0
        Compression::Deflate => 8
        Compression::Other(comp_method) => comp_method
      }
      let (dos_time, dos_date) = unix_to_dos_datetime(mem.mtime)
      let entry = write_u32_le(central_directory_signature) + // Signature
        write_u16_le(file.version_made_by) + // Version made by
        write_u16_le(file.version_needed_to_extract) + // Version needed
        write_u16_le(file.gp_flags) + // GP flags
        write_u16_le(compression_method) + // Compression method
        write_u16_le(dos_time) + // Last mod time
        write_u16_le(dos_date) + // Last mod date
        write_u32_le(file.decompressed_crc32.to_int()) + // CRC-32
        write_u32_le(file.compressed_size) + // Compressed size
        write_u32_le(file.decompressed_size) + // Uncompressed size
        write_u16_le(path_bytes.length()) + // Filename length
        write_u16_le(0) + // Extra field length
        write_u16_le(0) + // File comment length
        write_u16_le(0) + // Disk number start
        write_u16_le(0) + // Internal file attrs
        write_u32_le(mem.mode << 16) + // External file attrs
        write_u32_le(local_header_offset) // Local header offset
      @deflate.ok(entry + path_bytes)
    }
  }
}

// Write end of central directory record

///|
fn write_eocd_record(
  entry_count : Int,
  cd_size : Int,
  cd_offset : Int,
) -> String {
  write_u32_le(end_of_central_directory_signature) + // Signature
  write_u16_le(0) + // Disk number
  write_u16_le(0) + // Disk with central directory
  write_u16_le(entry_count) + // Entries on this disk
  write_u16_le(entry_count) + // Total entries
  write_u32_le(cd_size) + // Central directory size
  write_u32_le(cd_offset) + // Central directory offset
  write_u16_le(0) // Comment length
}

// Binary parsing utilities

///|
fn write_u16_le(value : Int) -> String {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  b0.unsafe_to_char().to_string() + b1.unsafe_to_char().to_string()
}

///|
fn write_u32_le(value : Int) -> String {
  let b0 = value & 0xff
  let b1 = (value >> 8) & 0xff
  let b2 = (value >> 16) & 0xff
  let b3 = (value >> 24) & 0xff
  b0.unsafe_to_char().to_string() +
  b1.unsafe_to_char().to_string() +
  b2.unsafe_to_char().to_string() +
  b3.unsafe_to_char().to_string()
}

// ZIP file format constants

///|
let local_file_header_signature : Int = 0x04034b50

///|
let central_directory_signature : Int = 0x02014b50

///|
let end_of_central_directory_signature : Int = 0x06054b50

// Check if string has ZIP magic bytes

///|
pub fn string_has_magic(s : StringView) -> Bool {
  bytes_has_magic(@utf8.encode(s))
}

///|
fn bytes_has_magic(data : Bytes) -> Bool {
  if data.length() < 4 {
    return false
  }
  if data[0] == 0x50 && data[1] == 0x4b && data[2] == 0x03 && data[3] == 0x04 {
    return true
  }
  if data[0] == 0x50 && data[1] == 0x4b && data[2] == 0x05 && data[3] == 0x06 {
    return true
  }
  false
}

// Find end of central directory record

///|
fn find_eocd_bytes(data : Bytes) -> Int? {
  let len = data.length()
  if len < 22 {
    return None
  }

  // Search backwards from end of file
  for i = len - 22; i >= 0; i = i - 1 {
    if i + 3 < len {
      let sig = read_u32_le_bytes(data, i)
      if sig == end_of_central_directory_signature {
        return Some(i)
      }
    }
  }
  None
}

// Parse ZIP file

///|
pub fn of_binary(data : Bytes) -> @deflate.Result[Archive, String] {
  if data.length() < 22 {
    return @deflate.err("File too small to be a valid ZIP archive")
  }

  // Check for ZIP magic bytes
  if !bytes_has_magic(data) {
    return @deflate.err("Not a valid ZIP archive - missing magic bytes")
  }

  // Find end of central directory record
  match find_eocd_bytes(data) {
    None => @deflate.err("Could not find end of central directory record")
    Some(eocd_offset) => {
      // Parse EOCD record
      let cd_entries = read_u16_le_bytes(data, eocd_offset + 10)
      let _cd_size = read_u32_le_bytes(data, eocd_offset + 12)
      let cd_offset = read_u32_le_bytes(data, eocd_offset + 16)
      if cd_entries == 0 {
        // Empty archive
        @deflate.ok(Archive::new())
      } else {
        // Parse central directory entries
        parse_central_directory_bytes(data, cd_offset, cd_entries)
      }
    }
  }
}

// Parse archive from bytes (more efficient for binary data)

///|
pub fn of_bytes(data : Bytes) -> @deflate.Result[Archive, String] {
  of_binary(data)
}

// Parse central directory entries

///|
fn parse_central_directory_bytes(
  data : Bytes,
  cd_offset : Int,
  entry_count : Int,
) -> @deflate.Result[Archive, String] {
  let mut archive = Archive::new()
  let mut offset = cd_offset
  for i = 0; i < entry_count; i = i + 1 {
    match parse_central_directory_entry_bytes(data, offset) {
      @deflate.Ok((mem, next_offset)) => {
        archive = archive.add(mem)
        offset = next_offset
      }
      @deflate.Err(error) =>
        return @deflate.err(
          "Failed to parse central directory entry " +
          i.to_string() +
          ": " +
          error,
        )
    }
  }
  @deflate.ok(archive)
}

// Parse a single central directory entry

///|
fn parse_central_directory_entry_bytes(
  data : Bytes,
  offset : Int,
) -> @deflate.Result[(Member, Int), String] {
  if offset + 46 > data.length() {
    return @deflate.err("Central directory entry extends beyond file")
  }
  let signature = read_u32_le_bytes(data, offset)
  if signature != central_directory_signature {
    return @deflate.err("Invalid central directory entry signature")
  }
  let version_made_by = read_u16_le_bytes(data, offset + 4)
  let version_needed = read_u16_le_bytes(data, offset + 6)
  let gp_flags = read_u16_le_bytes(data, offset + 8)
  let compression_method = read_u16_le_bytes(data, offset + 10)
  let _last_mod_time = read_u16_le_bytes(data, offset + 12)
  let _last_mod_date = read_u16_le_bytes(data, offset + 14)
  let crc32 = read_u32_le_bytes(data, offset + 16)
  let compressed_size = read_u32_le_bytes(data, offset + 20)
  let uncompressed_size = read_u32_le_bytes(data, offset + 24)
  let filename_length = read_u16_le_bytes(data, offset + 28)
  let extra_field_length = read_u16_le_bytes(data, offset + 30)
  let file_comment_length = read_u16_le_bytes(data, offset + 32)
  let external_file_attrs = read_u32_le_bytes(data, offset + 38)
  let local_header_offset = read_u32_le_bytes(data, offset + 42)

  // Read filename
  let filename_start = offset + 46
  if filename_start + filename_length > data.length() {
    return @deflate.err("Filename extends beyond file")
  }
  let filename_bytes = data[filename_start:filename_start + filename_length]
  let filename = @utf8.decode_lossy(filename_bytes)

  // Determine compression type
  let compression = match compression_method {
    0 => Compression::Stored
    8 => Compression::Deflate
    _ => Compression::Other(compression_method)
  }

  // Read file data from local header
  match read_file_data_bytes(data, local_header_offset, compressed_size) {
    @deflate.Ok(file_data) => {
      // Create file object
      let file = {
        compression,
        start: 0,
        compressed_size,
        compressed_bytes: file_data,
        decompressed_size: uncompressed_size,
        decompressed_crc32: crc32.to_int64(),
        version_made_by,
        version_needed_to_extract: version_needed,
        gp_flags,
      }

      // Determine if it's a directory
      let is_directory = filename.strip_suffix("/") is Some(_) ||
        (external_file_attrs & 0x10) != 0
      let kind = if is_directory {
        MemberKind::Dir
      } else {
        MemberKind::File(file)
      }

      // Create member
      let mem = {
        path: filename,
        mode: if is_directory {
          0o755
        } else {
          0o644
        },
        mtime: dos_datetime_to_unix(_last_mod_time, _last_mod_date),
        kind,
      }
      let next_offset = offset +
        46 +
        filename_length +
        extra_field_length +
        file_comment_length
      @deflate.ok((mem, next_offset))
    }
    @deflate.Err(error) => @deflate.err("Failed to read file data: " + error)
  }
}

// Read file data from local header

///|
fn read_file_data_bytes(
  data : Bytes,
  local_header_offset : Int,
  compressed_size : Int,
) -> @deflate.Result[Bytes, String] {
  if local_header_offset + 30 > data.length() {
    return @deflate.err("Local header extends beyond file")
  }
  let signature = read_u32_le_bytes(data, local_header_offset)
  if signature != local_file_header_signature {
    return @deflate.err("Invalid local file header signature")
  }
  let filename_length = read_u16_le_bytes(data, local_header_offset + 26)
  let extra_field_length = read_u16_le_bytes(data, local_header_offset + 28)
  let file_data_offset = local_header_offset +
    30 +
    filename_length +
    extra_field_length
  if file_data_offset + compressed_size > data.length() {
    return @deflate.err("File data extends beyond archive")
  }
  let file_data = data[file_data_offset:file_data_offset + compressed_size]
  @deflate.ok(file_data.to_bytes())
}
