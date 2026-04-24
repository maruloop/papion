///|
fn decode_base64_content(content : String) -> Result[Bytes, String] {
  Ok(@base64.decode(content, ignore_whitespace=true)) catch {
    _ => Err("failed to decode GitHub contents payload")
  }
}

///|
fn extract_content_field(
  body : String,
  path : String,
) -> Result[Bytes, (Int, String)] {
  let json = try? @json.parse(body)
  let json = match json {
    Ok(json) => json
    Err(err) =>
      return Err((0, "failed to parse GitHub response for \{path}: \{err}"))
  }
  match json {
    { "content": String(content), .. } =>
      decode_base64_content(content).map_err(fn(message) { (0, message) })
    { "content": _, .. } =>
      Err(
        (
          0,
          "GitHub response for \{path} did not contain a string content field",
        ),
      )
    _ => Err((0, "GitHub response for \{path} did not contain a content field"))
  }
}

///|
fn github_token() -> String? {
  match @env.get_env_var("GITHUB_TOKEN") {
    Some("") => None
    token => token
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
fn percent_encode_path_component(component : String) -> String {
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

///|
fn github_contents_url(
  owner : String,
  repo : String,
  git_ref : String,
  filename : String,
) -> Result[String, (Int, String)] {
  try {
    let url = @url.Url::parse("https://api.github.com")
    let enc_owner = percent_encode_path_component(owner)
    let enc_repo = percent_encode_path_component(repo)
    let enc_filename = filename
      .split("/")
      .map(fn(segment) { percent_encode_path_component(segment.to_string()) })
      .to_array()
      .join("/")
    url.set_pathname("/repos/\{enc_owner}/\{enc_repo}/contents/\{enc_filename}")
    let params = @url.UrlSearchParams::new()
    params.set("ref", git_ref)
    url.set_search_params(params)
    Ok(url.to_string())
  } catch {
    _ => Err((0, "failed to build GitHub contents URL for \{filename}"))
  }
}

///|
priv suberror HttpError {
  HttpError((Int, String))
}

///|
fn fetch_contents(
  owner : String,
  repo : String,
  git_ref : String,
  filename : String,
) -> Result[Bytes, (Int, String)] {
  let url = match github_contents_url(owner, repo, git_ref, filename) {
    Ok(url) => url
    Err(err) => return Err(err)
  }
  let mut result : Result[Bytes, (Int, String)] = Err(
    (0, "request was not executed"),
  )
  @async.run_async_main(() => {
    let headers = {
      "User-Agent": @papion.cli_user_agent(),
      "Accept": "application/vnd.github+json",
    }
    if github_token() is Some(token) {
      headers["Authorization"] = "Bearer \{token}"
    }
    let request : Result[Bytes, (Int, String)] = try {
      let bytes = @async.retry(
        ExponentialDelay(initial=1000, factor=2.0, maximum=10000),
        max_retry=3,
        fatal_error=fn(err) {
          match err {
            HttpError((code, _)) => code >= 400 && code < 500 && code != 429
            _ => false
          }
        },
        () => {
          let pair = @async.with_timeout(30000, () => @http.get(url, headers~))
          let (response, body) = pair
          if response.code == 200 {
            match extract_content_field(body.text(), filename) {
              Ok(bytes) => bytes
              Err(err) => raise HttpError(err)
            }
          } else {
            raise HttpError(
              (
                response.code,
                "failed to fetch \{filename} from GitHub (\{response.code} \{response.reason})",
              ),
            )
          }
        },
      )
      Ok(bytes)
    } catch {
      HttpError(err) => Err(err)
      err => Err((0, "failed to fetch \{filename} from GitHub: \{err}"))
    }
    match request {
      Ok(bytes) => result = Ok(bytes)
      Err(err) => result = Err(err)
    }
  })
  result
}

///|
fn normalize_action_path(path : String?) -> String {
  match path {
    None => ""
    Some(p) => {
      let trimmed = p.trim(chars="/")
      if trimmed.is_empty() {
        ""
      } else {
        "\{trimmed}/"
      }
    }
  }
}

///|
pub fn fetch_action_yml(
  owner : String,
  repo : String,
  git_ref : String,
  path : String?,
) -> Result[String, String] {
  let prefix = normalize_action_path(path)
  let bytes = match
    fetch_contents(owner, repo, git_ref, "\{prefix}action.yml") {
    Ok(bytes) => bytes
    Err((404, _)) =>
      match fetch_contents(owner, repo, git_ref, "\{prefix}action.yaml") {
        Ok(bytes) => bytes
        Err((_, err)) => return Err(err)
      }
    Err((_, err)) => return Err(err)
  }
  let action_yml = try? @utf8.decode(bytes)
  match action_yml {
    Ok(action_yml) => Ok(action_yml)
    Err(_) => Err("GitHub action file is not valid UTF-8")
  }
}
