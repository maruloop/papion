///|
#borrow(path, mode)
extern "c" fn fopen_ffi(path : Bytes, mode : Bytes) -> Int64 = "moonbit_fopen_ffi"

///|
#borrow(ptr)
extern "c" fn is_null_ffi(ptr : Int64) -> Bool = "moonbit_is_null"

///|
#borrow(ptr)
extern "c" fn fread_ffi(
  ptr : Bytes,
  size : Int64,
  nitems : Int64,
  stream : Int64,
) -> Int64 = "moonbit_fread_ffi"

///|
extern "c" fn fseek_ffi(stream : Int64, offset : Int64, whence : Int) -> Int = "moonbit_fseek_ffi"

///|
extern "c" fn ftell_ffi(stream : Int64) -> Int64 = "moonbit_ftell_ffi"

///|
extern "c" fn fclose_ffi(stream : Int64) -> Int = "moonbit_fclose_ffi"

///|
extern "c" fn get_error_message_ffi() -> Bytes = "moonbit_get_error_message"

///|
let seek_set : Int = 0

///|
let seek_end : Int = 2

///|
fn c_string_bytes(str : String) -> Bytes {
  let bytes = @utf8.encode(str).to_array()
  bytes.push(0)
  Bytes::from_array(bytes)
}

///|
let max_config_file_size : Int64 = 10L * 1024L * 1024L

///|
let file_read_chunk_size : Int64 = 8192L

///|
fn read_file(path : String) -> Result[Bytes, String] {
  let file = fopen_ffi(c_string_bytes(path), b"rb")
  if is_null_ffi(file) {
    return Err(
      "failed to open \{path}: \{@utf8.decode_lossy(get_error_message_ffi())}",
    )
  }
  if fseek_ffi(file, 0L, seek_end) != 0 {
    ignore(fclose_ffi(file))
    return Err("failed to seek to end of \{path}")
  }
  let size = ftell_ffi(file)
  if size < 0L {
    ignore(fclose_ffi(file))
    return Err("failed to get size of \{path}")
  }
  if size > max_config_file_size {
    ignore(fclose_ffi(file))
    return Err("config file exceeds maximum size of 10 MiB: \{path}")
  }
  if fseek_ffi(file, 0L, seek_set) != 0 {
    ignore(fclose_ffi(file))
    return Err("failed to seek to start of \{path}")
  }
  let buffer = @buffer.new(size_hint=size.to_int())
  let chunk = Bytes::new(
    if size < file_read_chunk_size {
      size.to_int()
    } else {
      file_read_chunk_size.to_int()
    },
  )
  let mut total_read = 0L
  while total_read < size {
    let remaining = size - total_read
    let n = fread_ffi(
      chunk,
      1L,
      if remaining < file_read_chunk_size {
        remaining
      } else {
        file_read_chunk_size
      },
      file,
    )
    if n <= 0L {
      ignore(fclose_ffi(file))
      return Err("failed to read \{path}")
    }
    buffer.write_bytesview(chunk[:n.to_int()])
    total_read = total_read + n
  }
  ignore(fclose_ffi(file))
  Ok(buffer.to_bytes())
}
