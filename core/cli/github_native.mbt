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
fn github_contents_url(
  owner : String,
  repo : String,
  git_ref : String,
  filename : String,
) -> Result[String, (Int, String)] {
  try {
    let url = @url.Url::parse("https://api.github.com")
    url.set_pathname("/repos/\{owner}/\{repo}/contents/\{filename}")
    let params = @url.UrlSearchParams::new()
    params.set("ref", git_ref)
    url.set_search_params(params)
    Ok(url.to_string())
  } catch {
    _ => Err((0, "failed to build GitHub contents URL for \{filename}"))
  }
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
    let request : Result[Unit, (Int, String)] = try {
      let (response, body) = @http.get(url, headers~)
      if response.code == 200 {
        result = extract_content_field(body.text(), filename)
      } else {
        result = Err(
          (
            response.code,
            "failed to fetch \{filename} from GitHub (\{response.code} \{response.reason})",
          ),
        )
      }
      Ok(())
    } catch {
      err => Err((0, "failed to fetch \{filename} from GitHub: \{err}"))
    }
    if request is Err(err) {
      result = Err(err)
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
