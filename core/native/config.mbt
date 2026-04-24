///|
fn parse_pattern_list(
  value : @toml.TomlValue?,
  field_name : String,
) -> Result[Array[String], String] {
  match value {
    None => Ok([])
    Some(@toml.TomlArray(items)) => {
      let acc : Array[String] = []
      for item in items {
        match item {
          @toml.TomlString(s) => acc.push(s)
          _ => return Err("invalid entry in '\{field_name}': expected string")
        }
      }
      Ok(acc)
    }
    Some(_) => Err("invalid '\{field_name}' field: expected array")
  }
}

///|
fn parse_policy_toml(value : @toml.TomlValue) -> Result[@papion.Policy, String] {
  let root = match value {
    @toml.TomlTable(entries) => entries
    _ => return Err("expected TOML table for Policy")
  }
  let obj = match root.get("policy") {
    None => root
    Some(@toml.TomlTable(inner)) => inner
    Some(_) => return Err("invalid 'policy' field: expected table")
  }
  let sha_pinning = match obj.get("sha_pinning") {
    Some(@toml.TomlBoolean(b)) => b
    None => true
    Some(_) => return Err("invalid 'sha_pinning' field: expected boolean")
  }
  let allowed = match parse_pattern_list(obj.get("allowed"), "allowed") {
    Ok(allowed) => allowed
    Err(err) => return Err(err)
  }
  let disallowed = match
    parse_pattern_list(obj.get("disallowed"), "disallowed") {
    Ok(disallowed) => disallowed
    Err(err) => return Err(err)
  }
  @papion.Policy::{ sha_pinning, allowed, disallowed }.normalized()
}

///|
pub fn load_config(config_path : String?) -> Result[@papion.Policy, String] {
  match config_path {
    None => Ok(@papion.Policy::default())
    Some(path) => {
      let bytes = match read_file(path) {
        Ok(bytes) => bytes
        Err(err) => return Err(err)
      }
      let toml_str = try? @utf8.decode(bytes)
      match toml_str {
        Ok(toml_str) => {
          let value = try? @toml.parse(toml_str)
          match value {
            Ok(value) => parse_policy_toml(value)
            Err(err) => Err(err.to_string())
          }
        }
        Err(_) => Err("config file is not valid UTF-8: \{path}")
      }
    }
  }
}
