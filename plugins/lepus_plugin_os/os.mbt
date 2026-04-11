///|
extern "C" fn os_name_ffi() -> Bytes = "lp_os_name"

///|
extern "C" fn arch_name_ffi() -> Bytes = "lp_os_arch"

///|
pub fn os_name() -> String {
  @utf8.decode_lossy(os_name_ffi()[:])
}

///|
pub fn arch_name() -> String {
  @utf8.decode_lossy(arch_name_ffi()[:])
}
