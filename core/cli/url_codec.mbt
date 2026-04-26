///|
fn hex_value(ch : Char) -> Int? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else {
    None
  }
}

///|
pub fn percent_decode_url_path_segment(
  segment : String,
) -> Result[String, String] {
  let bytes = @buffer.new(size_hint=segment.length())
  let chars = segment.iter()
  while chars.next() is Some(ch) {
    if ch == '%' {
      let hi = match chars.next() {
        Some(ch) => ch
        None => return Err("invalid GitHub URL: invalid percent-encoding")
      }
      let lo = match chars.next() {
        Some(ch) => ch
        None => return Err("invalid GitHub URL: invalid percent-encoding")
      }
      let hi = match hex_value(hi) {
        Some(value) => value
        None => return Err("invalid GitHub URL: invalid percent-encoding")
      }
      let lo = match hex_value(lo) {
        Some(value) => value
        None => return Err("invalid GitHub URL: invalid percent-encoding")
      }
      bytes.write_byte((hi * 16 + lo).to_byte())
    } else if ch.to_int() <= 0x7F {
      bytes.write_byte(ch.to_int().to_byte())
    } else {
      bytes.write_bytes(@utf8.encode([ch]))
    }
  }
  let decoded : Result[String, _] = try? @utf8.decode(bytes.to_bytes())
  match decoded {
    Ok(decoded) => Ok(decoded)
    Err(_) => Err("invalid GitHub URL: invalid UTF-8 in percent-encoding")
  }
}

///|
fn is_unreserved_path_byte(byte : Byte) -> Bool {
  (byte >= b'A' && byte <= b'Z') ||
  (byte >= b'a' && byte <= b'z') ||
  (byte >= b'0' && byte <= b'9') ||
  byte == b'-' ||
  byte == b'.' ||
  byte == b'_' ||
  byte == b'~'
}

///|
fn percent_encode_hex_digit(value : Byte) -> Char {
  if value < 10 {
    (value.to_int() + '0'.to_int()).unsafe_to_char()
  } else {
    (value.to_int() - 10 + 'A'.to_int()).unsafe_to_char()
  }
}

///|
pub fn percent_encode_path_component(component : String) -> String {
  let bytes = @utf8.encode(component).to_array()
  let builder = StringBuilder::new(size_hint=bytes.length() * 3)
  for byte in bytes {
    if is_unreserved_path_byte(byte) {
      builder.write_char(byte.to_int().unsafe_to_char())
    } else {
      builder.write_char('%')
      builder.write_char(percent_encode_hex_digit(byte / 16))
      builder.write_char(percent_encode_hex_digit(byte % 16))
    }
  }
  builder.to_string()
}
