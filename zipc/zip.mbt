// Simplified ZIP module - self-contained implementation

// Basic ZIP types

///|
pub enum Compression {
  Stored
  Deflate
  Other(Int)
}

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
pub(all) enum MemberKind {
  Dir
  File(File)
}

///|
pub struct Member {
  path : String
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
pub const DOS_EPOCH : Ptime = 315532800 // 1980-01-01 00:00:00 UTC

///|
pub const MAX_FILE_SIZE : Int = 2147483647 // Use max int instead of 4GB

///|
pub const MAX_MEMBERS : Int = 65535 // ZIP32 limit

///|
pub const MAX_PATH_LENGTH : Int = 65535

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
pub fn Archive::add(self : Archive, mem : Member) -> Unit {
  self.members[mem.path] = mem
}

///|
pub fn Archive::find(self : Archive, path : String) -> Member? {
  self.members.get(path)
}

///|
pub fn Archive::mem(self : Archive, path : String) -> Bool {
  self.members.contains(path)
}

///|
pub fn Archive::remove(self : Archive, path : String) -> Archive {
  self.members.remove(path)
  self
}

// File operations

///|
pub fn File::from_string(s : String) -> File raise {
  let data = @utf8.encode(s)
  let len = data.length()
  if len > MAX_FILE_SIZE {
    fail(
      "File size exceeds maximum allowed (" +
      MAX_FILE_SIZE.to_string() +
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
  if len > MAX_FILE_SIZE {
    fail(
      "File size exceeds maximum allowed (" +
      MAX_FILE_SIZE.to_string() +
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
pub fn File::deflate_of_binary_string(
  s : String,
  level : @deflate.Level,
) -> File raise {
  let data = @utf8.encode(s)
  let len = data.length()
  if len > MAX_FILE_SIZE {
    fail(
      "File size exceeds maximum allowed (" +
      MAX_FILE_SIZE.to_string() +
      " bytes)",
    )
  }

  // Compress using deflate
  let compressed_data = @deflate.deflate_of_bytes(data, level)
  let crc = @crc32.bytes(data)
  {
    compression: Compression::Deflate,
    start: 0,
    compressed_size: compressed_data.length(),
    compressed_bytes: compressed_data,
    decompressed_size: len,
    decompressed_crc32: crc.0,
    version_made_by: 0x314, // UNIX, ZIP 2.0
    version_needed_to_extract: 20, // ZIP 2.0
    gp_flags: 0x800, // UTF-8 filename
  }
}

// Create deflate-compressed file from bytes (more efficient for binary data)

///|
pub fn deflate_of_bytes(data : Bytes, level : @deflate.Level) -> File raise {
  let len = data.length()
  if len > MAX_FILE_SIZE {
    fail(
      "File size exceeds maximum allowed (" +
      MAX_FILE_SIZE.to_string() +
      " bytes)",
    )
  }

  // Compress using deflate directly on bytes (more efficient)
  let compressed_data = @deflate.deflate_of_bytes(data, level)
  let crc = @crc32.bytes(data)
  {
    compression: Compression::Deflate,
    start: 0,
    compressed_size: compressed_data.length(),
    compressed_bytes: compressed_data,
    decompressed_size: len,
    decompressed_crc32: crc.0,
    version_made_by: 0x314, // UNIX, ZIP 2.0
    version_needed_to_extract: 20, // ZIP 2.0
    gp_flags: 0x800, // UTF-8 filename
  }
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
pub fn File::to_bytes(self : File) -> Bytes raise {
  if !self.can_extract() {
    fail("Unsupported compression format")
  }
  match self.compression {
    Compression::Stored => {
      let data_view = self.compressed_bytes[self.start:self.start +
        self.compressed_size]
      // Convert view back to bytes
      data_view.to_bytes()
    }
    Compression::Deflate =>
      // Use bytes-based decompression for better performance
      @deflate.deflate_decompress_bytes(
        self.compressed_bytes,
        self.decompressed_size,
      )
    _ => fail("Unsupported compression format")
  }
}

// Member operations

///|
pub fn Member::make(path : String, kind : MemberKind) -> Member raise {
  if path.length() > MAX_PATH_LENGTH {
    fail(
      "Path length exceeds maximum allowed (" +
      MAX_PATH_LENGTH.to_string() +
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
  {
    path: final_path,
    mtime: DOS_EPOCH, // Default mtime
    mode: default_mode,
    kind,
  }
}

///|
pub fn Member::path(self : Member) -> String {
  self.path
}

///|
pub fn Member::mode(self : Member) -> Mode {
  self.mode
}

///|
pub fn Member::mtime(self : Member) -> Ptime {
  self.mtime
}

///|
pub fn Member::kind(self : Member) -> MemberKind {
  self.kind
}

// Archive encoding/decoding

///|
pub fn Archive::to_binary_string(self : Archive) -> StringView raise {
  @utf8.decode_lossy(self.to_bytes())
}

// Convert archive to bytes

///|
pub fn Archive::to_bytes(self : Archive) -> Bytes raise {
  let count = self.member_count()
  if count > MAX_MEMBERS {
    fail("Archive has too many members ({count}), max is {MAX_MEMBERS}")
  }
  if self.is_empty() {
    // Empty ZIP file: just EOCD record (22 bytes)
    write_eocd_bytes(0, 0, 0)
  } else {
    self.build_zip_bytes()
  }
}

// Build a complete ZIP file with local headers, central directory, and EOCD

///|
fn Archive::build_zip_bytes(self : Archive) -> Bytes {
  let local_header_offsets : Array[Int] = []
  let member_list : Array[Member] = []
  let parts : Array[Bytes] = []

  // Collect all members
  self.members.each(fn(_, mem) { member_list.push(mem) })

  // Write local file headers and data
  let mut current_offset = 0
  for mem in member_list {
    local_header_offsets.push(current_offset)
    let local_header_data = write_local_file_header_bytes(mem)
    current_offset += local_header_data.length()
    parts.push(local_header_data)
  }

  // Write central directory
  let central_directory_offset = current_offset
  let cd_parts : Array[Bytes] = []
  for i = 0; i < member_list.length(); i = i + 1 {
    let mem = member_list[i]
    let local_offset = local_header_offsets[i]
    let cd_entry = write_central_directory_entry_bytes(mem, local_offset)
    current_offset += cd_entry.length()
    cd_parts.push(cd_entry)
  }

  let cd_size = current_offset - central_directory_offset

  // Write end of central directory record
  let eocd = write_eocd_bytes(
    member_list.length(),
    cd_size,
    central_directory_offset,
  )

  // Concatenate all parts
  let all_parts = parts + cd_parts + [eocd]
  concat_bytes(all_parts)
}

// Write local file header as Bytes

///|
fn write_local_file_header_bytes(mem : Member) -> Bytes {
  let path_bytes = @utf8.encode(mem.path)
  let path_len = path_bytes.length()
  match mem.kind {
    MemberKind::Dir => {
      let (dos_time, dos_date) = unix_to_dos_datetime(mem.mtime)
      concat_bytes([
        write_u32_le_bytes(local_file_header_signature),
        write_u16_le_bytes(20), // Version needed
        write_u16_le_bytes(0x800), // GP flags (UTF-8)
        write_u16_le_bytes(0), // Compression method (stored)
        write_u16_le_bytes(dos_time),
        write_u16_le_bytes(dos_date),
        write_u32_le_bytes(0), // CRC-32
        write_u32_le_bytes(0), // Compressed size
        write_u32_le_bytes(0), // Uncompressed size
        write_u16_le_bytes(path_len),
        write_u16_le_bytes(0), // Extra field length
        path_bytes,
      ])
    }
    MemberKind::File(file) => {
      let compression_method = match file.compression {
        Compression::Stored => 0
        Compression::Deflate => 8
        Compression::Other(m) => m
      }
      let (dos_time, dos_date) = unix_to_dos_datetime(mem.mtime)
      concat_bytes([
        write_u32_le_bytes(local_file_header_signature),
        write_u16_le_bytes(file.version_needed_to_extract),
        write_u16_le_bytes(file.gp_flags),
        write_u16_le_bytes(compression_method),
        write_u16_le_bytes(dos_time),
        write_u16_le_bytes(dos_date),
        write_u32_le_bytes(file.decompressed_crc32.to_int()),
        write_u32_le_bytes(file.compressed_size),
        write_u32_le_bytes(file.decompressed_size),
        write_u16_le_bytes(path_len),
        write_u16_le_bytes(0), // Extra field length
        path_bytes,
        file.compressed_bytes,
      ])
    }
  }
}

// Write central directory entry as Bytes

///|
fn write_central_directory_entry_bytes(
  mem : Member,
  local_header_offset : Int,
) -> Bytes {
  let path_bytes = @utf8.encode(mem.path)
  let path_len = path_bytes.length()
  match mem.kind {
    MemberKind::Dir => {
      let (dos_time, dos_date) = unix_to_dos_datetime(mem.mtime)
      concat_bytes([
        write_u32_le_bytes(central_directory_signature),
        write_u16_le_bytes(0x314), // Version made by (Unix, ZIP 2.0)
        write_u16_le_bytes(20), // Version needed
        write_u16_le_bytes(0x800), // GP flags (UTF-8)
        write_u16_le_bytes(0), // Compression method
        write_u16_le_bytes(dos_time),
        write_u16_le_bytes(dos_date),
        write_u32_le_bytes(0), // CRC-32
        write_u32_le_bytes(0), // Compressed size
        write_u32_le_bytes(0), // Uncompressed size
        write_u16_le_bytes(path_len),
        write_u16_le_bytes(0), // Extra field length
        write_u16_le_bytes(0), // File comment length
        write_u16_le_bytes(0), // Disk number start
        write_u16_le_bytes(0), // Internal file attrs
        write_u32_le_bytes((mem.mode << 16) | 0x10), // External file attrs (directory)
        write_u32_le_bytes(local_header_offset),
        path_bytes,
      ])
    }
    MemberKind::File(file) => {
      let compression_method = match file.compression {
        Compression::Stored => 0
        Compression::Deflate => 8
        Compression::Other(m) => m
      }
      let (dos_time, dos_date) = unix_to_dos_datetime(mem.mtime)
      concat_bytes([
        write_u32_le_bytes(central_directory_signature),
        write_u16_le_bytes(file.version_made_by),
        write_u16_le_bytes(file.version_needed_to_extract),
        write_u16_le_bytes(file.gp_flags),
        write_u16_le_bytes(compression_method),
        write_u16_le_bytes(dos_time),
        write_u16_le_bytes(dos_date),
        write_u32_le_bytes(file.decompressed_crc32.to_int()),
        write_u32_le_bytes(file.compressed_size),
        write_u32_le_bytes(file.decompressed_size),
        write_u16_le_bytes(path_len),
        write_u16_le_bytes(0), // Extra field length
        write_u16_le_bytes(0), // File comment length
        write_u16_le_bytes(0), // Disk number start
        write_u16_le_bytes(0), // Internal file attrs
        write_u32_le_bytes(mem.mode << 16), // External file attrs
        write_u32_le_bytes(local_header_offset),
        path_bytes,
      ])
    }
  }
}

// Write end of central directory record as Bytes

///|
fn write_eocd_bytes(entry_count : Int, cd_size : Int, cd_offset : Int) -> Bytes {
  concat_bytes([
    write_u32_le_bytes(end_of_central_directory_signature),
    write_u16_le_bytes(0), // Disk number
    write_u16_le_bytes(0), // Disk with central directory
    write_u16_le_bytes(entry_count), // Entries on this disk
    write_u16_le_bytes(entry_count), // Total entries
    write_u32_le_bytes(cd_size), // Central directory size
    write_u32_le_bytes(cd_offset), // Central directory offset
    write_u16_le_bytes(0), // Comment length
  ])
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
pub fn of_binary(data : Bytes) -> Archive raise {
  if data.length() < 22 {
    fail("File too small to be a valid ZIP archive")
  }

  // Check for ZIP magic bytes
  if !bytes_has_magic(data) {
    fail("Not a valid ZIP archive - missing magic bytes")
  }

  // Find end of central directory record
  match find_eocd_bytes(data) {
    None => fail("Could not find end of central directory record")
    Some(eocd_offset) => {
      // Parse EOCD record
      let cd_entries = read_u16_le_bytes(data, eocd_offset + 10)
      let _cd_size = read_u32_le_bytes(data, eocd_offset + 12)
      let cd_offset = read_u32_le_bytes(data, eocd_offset + 16)
      if cd_entries == 0 {
        // Empty archive
        Archive::new()
      } else {
        // Parse central directory entries
        parse_central_directory_bytes(data, cd_offset, cd_entries)
      }
    }
  }
}

// Parse archive from bytes (more efficient for binary data)

///|
pub fn of_bytes(data : Bytes) -> Archive raise {
  of_binary(data)
}

// Parse central directory entries

///|
fn parse_central_directory_bytes(
  data : Bytes,
  cd_offset : Int,
  entry_count : Int,
) -> Archive raise {
  let archive = Archive::new()
  let mut offset = cd_offset
  for i = 0; i < entry_count; i = i + 1 {
    let (mem, next_offset) = parse_central_directory_entry_bytes(data, offset)
    archive.add(mem)
    offset = next_offset
  }
  archive
}

// Parse a single central directory entry

///|
fn parse_central_directory_entry_bytes(
  data : Bytes,
  offset : Int,
) -> (Member, Int) raise {
  if offset + 46 > data.length() {
    fail("Central directory entry extends beyond file")
  }
  let signature = read_u32_le_bytes(data, offset)
  if signature != central_directory_signature {
    fail("Invalid central directory entry signature")
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
    fail("Filename extends beyond file")
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
  let file_data = read_file_data_bytes(
    data, local_header_offset, compressed_size,
  )

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
  let kind = if is_directory { MemberKind::Dir } else { MemberKind::File(file) }

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
  (mem, next_offset)
}

// Read file data from local header

///|
fn read_file_data_bytes(
  data : Bytes,
  local_header_offset : Int,
  compressed_size : Int,
) -> Bytes raise {
  if local_header_offset + 30 > data.length() {
    fail("Local header extends beyond file")
  }
  let signature = read_u32_le_bytes(data, local_header_offset)
  if signature != local_file_header_signature {
    fail("Invalid local file header signature")
  }
  let filename_length = read_u16_le_bytes(data, local_header_offset + 26)
  let extra_field_length = read_u16_le_bytes(data, local_header_offset + 28)
  let file_data_offset = local_header_offset +
    30 +
    filename_length +
    extra_field_length
  if file_data_offset + compressed_size > data.length() {
    fail("File data extends beyond archive")
  }
  let file_data = data[file_data_offset:file_data_offset + compressed_size]
  file_data.to_bytes()
}
