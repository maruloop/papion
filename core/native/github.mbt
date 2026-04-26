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
fn extract_default_branch_field(
  body : String,
  owner : String,
  repo : String,
) -> Result[String, (Int, String)] {
  let json = try? @json.parse(body)
  let json = match json {
    Ok(json) => json
    Err(err) =>
      return Err(
        (
          0,
          "failed to parse GitHub repository response for \{owner}/\{repo}: \{err}",
        ),
      )
  }
  match json {
    { "default_branch": String(branch), .. } => Ok(branch)
    { "default_branch": _, .. } =>
      Err(
        (
          0,
          "GitHub repository response for \{owner}/\{repo} did not contain a string default_branch field",
        ),
      )
    _ =>
      Err(
        (
          0,
          "GitHub repository response for \{owner}/\{repo} did not contain a default_branch field",
        ),
      )
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
    let enc_owner = @cli.percent_encode_path_component(owner)
    let enc_repo = @cli.percent_encode_path_component(repo)
    let enc_filename = filename
      .split("/")
      .map(fn(segment) {
        @cli.percent_encode_path_component(segment.to_string())
      })
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
fn github_repo_url(
  owner : String,
  repo : String,
) -> Result[String, (Int, String)] {
  try {
    let url = @url.Url::parse("https://api.github.com")
    let enc_owner = @cli.percent_encode_path_component(owner)
    let enc_repo = @cli.percent_encode_path_component(repo)
    url.set_pathname("/repos/\{enc_owner}/\{enc_repo}")
    Ok(url.to_string())
  } catch {
    _ => Err((0, "failed to build GitHub repository URL for \{owner}/\{repo}"))
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
        @async.ExponentialDelay(initial=1000, factor=2.0, maximum=10000),
        max_retry=3,
        fatal_error=fn(err) {
          match err {
            HttpError((code, _)) =>
              code == 0 || (code >= 400 && code < 500 && code != 429)
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
fn fetch_default_branch(
  owner : String,
  repo : String,
) -> Result[String, (Int, String)] {
  let url = match github_repo_url(owner, repo) {
    Ok(url) => url
    Err(err) => return Err(err)
  }
  let mut result : Result[String, (Int, String)] = Err(
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
    let request : Result[String, (Int, String)] = try {
      let branch = @async.retry(
        @async.ExponentialDelay(initial=1000, factor=2.0, maximum=10000),
        max_retry=3,
        fatal_error=fn(err) {
          match err {
            HttpError((code, _)) =>
              code == 0 || (code >= 400 && code < 500 && code != 429)
            _ => false
          }
        },
        () => {
          let pair = @async.with_timeout(30000, () => @http.get(url, headers~))
          let (response, body) = pair
          if response.code == 200 {
            match extract_default_branch_field(body.text(), owner, repo) {
              Ok(branch) => branch
              Err(err) => raise HttpError(err)
            }
          } else {
            raise HttpError(
              (
                response.code,
                "failed to fetch repository metadata for \{owner}/\{repo} (\{response.code} \{response.reason})",
              ),
            )
          }
        },
      )
      Ok(branch)
    } catch {
      HttpError(err) => Err(err)
      err =>
        Err(
          (
            0,
            "failed to fetch repository metadata for \{owner}/\{repo}: \{err}",
          ),
        )
    }
    match request {
      Ok(branch) => result = Ok(branch)
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
fn tree_ref_fallbacks(
  git_ref : String,
  path : String?,
) -> Array[(String, String?)] {
  let fallbacks : Array[(String, String?)] = []
  let path_value = match path {
    Some(path_value) => path_value
    None => return fallbacks
  }
  let trimmed_path = path_value.trim(chars="/")
  if trimmed_path.is_empty() {
    return fallbacks
  }
  let segments : Array[String] = []
  for segment in trimmed_path.split("/") {
    let segment = segment.to_string()
    if !segment.is_empty() {
      segments.push(segment)
    }
  }
  if segments.is_empty() {
    return fallbacks
  }
  let mut candidate_ref = git_ref
  let mut i = 0
  while i < segments.length() {
    candidate_ref = candidate_ref + "/" + segments[i]
    let remaining_path = if i + 1 < segments.length() {
      Some(segments[i + 1:].join("/"))
    } else {
      None
    }
    fallbacks.push((candidate_ref, remaining_path))
    i += 1
  }
  fallbacks
}

///|
fn try_fetch_action_yml(
  owner : String,
  repo : String,
  git_ref : String,
  path : String?,
) -> Result[Bytes, (Int, String)] {
  let prefix = normalize_action_path(path)
  match fetch_contents(owner, repo, git_ref, "\{prefix}action.yml") {
    Ok(bytes) => Ok(bytes)
    Err((404, _)) =>
      fetch_contents(owner, repo, git_ref, "\{prefix}action.yaml")
    Err(err) => Err(err)
  }
}

///|
fn fetch_action_yml_with_fallback(
  owner : String,
  repo : String,
  git_ref : String,
  path : String?,
  allow_ref_fallback : Bool,
) -> Result[(Bytes, String), (Int, String)] {
  match try_fetch_action_yml(owner, repo, git_ref, path) {
    Ok(bytes) => Ok((bytes, git_ref))
    Err((404, message)) => {
      if !allow_ref_fallback {
        return Err((404, message))
      }
      let fallbacks = tree_ref_fallbacks(git_ref, path)
      // Cap fallback attempts to bound worst-case GitHub API requests.
      let fallback_limit = if fallbacks.length() < 2 {
        fallbacks.length()
      } else {
        2
      }
      for i = 0; i < fallback_limit; i = i + 1 {
        let (fallback_ref, fallback_path) = fallbacks[i]
        match try_fetch_action_yml(owner, repo, fallback_ref, fallback_path) {
          Ok(bytes) => return Ok((bytes, fallback_ref))
          Err((404, _)) => ()
          Err(err) => return Err(err)
        }
      }
      Err((404, message))
    }
    Err(err) => Err(err)
  }
}

///|
pub fn fetch_action_yml(
  owner : String,
  repo : String,
  git_ref : String?,
  path : String?,
  allow_ref_fallback : Bool,
) -> Result[(String, String), String] {
  let requested_git_ref = match git_ref {
    Some(git_ref) => git_ref
    None =>
      match fetch_default_branch(owner, repo) {
        Ok(branch) => branch
        Err((_, err)) => return Err(err)
      }
  }
  let (bytes, resolved_git_ref) = match
    fetch_action_yml_with_fallback(
      owner, repo, requested_git_ref, path, allow_ref_fallback,
    ) {
    Ok(result) => result
    Err((_, err)) => return Err(err)
  }
  let action_yml = try? @utf8.decode(bytes)
  match action_yml {
    Ok(action_yml) => Ok((action_yml, resolved_git_ref))
    Err(_) => Err("GitHub action file is not valid UTF-8")
  }
}
