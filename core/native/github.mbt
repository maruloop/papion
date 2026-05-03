///|
fn parse_github_json(
  body : String,
  description : String,
) -> Result[Json, (Int, String)] {
  let json = try? @json.parse(body)
  match json {
    Ok(json) => Ok(json)
    Err(err) => Err((0, "failed to parse GitHub \{description}: \{err}"))
  }
}

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
  let json = match parse_github_json(body, "response for \{path}") {
    Ok(json) => json
    Err(err) => return Err(err)
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
  let json = match
    parse_github_json(body, "repository response for \{owner}/\{repo}") {
    Ok(json) => json
    Err(err) => return Err(err)
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
fn extract_release_immutable_field(
  body : String,
  owner : String,
  repo : String,
  tag : String,
) -> Result[Bool, (Int, String)] {
  let json = match
    parse_github_json(body, "release response for \{owner}/\{repo}@\{tag}") {
    Ok(json) => json
    Err(err) => return Err(err)
  }
  match json {
    { "immutable": true, .. } => Ok(true)
    { "immutable": false, .. } => Ok(false)
    { "immutable": _, .. } =>
      Err(
        (
          0,
          "GitHub release response for \{owner}/\{repo}@\{tag} did not contain a boolean immutable field",
        ),
      )
    _ => Ok(false)
  }
}

///|
fn extract_matching_refs_field(
  body : String,
  owner : String,
  repo : String,
  ref_type : String,
) -> Result[Array[String], (Int, String)] {
  let json = match
    parse_github_json(body, "matching refs response for \{owner}/\{repo}") {
    Ok(json) => json
    Err(err) => return Err(err)
  }
  let expected_prefix = "refs/\{ref_type}/"
  match json {
    Array(arr) => {
      let refs : Array[String] = []
      for item in arr {
        match item {
          { "ref": String(ref_name), .. } => {
            if !ref_name.has_prefix(expected_prefix) {
              return Err(
                (
                  0,
                  "GitHub matching refs response for \{owner}/\{repo} contained ref outside refs/\{ref_type}/: \{ref_name}",
                ),
              )
            }
            refs.push(ref_name[expected_prefix.length():].to_owned())
          }
          { "ref": _, .. } =>
            return Err(
              (
                0,
                "GitHub matching refs response for \{owner}/\{repo} did not contain a string ref field",
              ),
            )
          _ =>
            return Err(
              (
                0,
                "GitHub matching refs response for \{owner}/\{repo} did not contain a ref field",
              ),
            )
        }
      }
      Ok(refs)
    }
    _ =>
      Err(
        (
          0,
          "GitHub matching refs response for \{owner}/\{repo} was not an array",
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
        @cli.percent_encode_path_component(segment.to_owned())
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
fn github_release_by_tag_url(
  owner : String,
  repo : String,
  tag : String,
) -> Result[String, (Int, String)] {
  try {
    let url = @url.Url::parse("https://api.github.com")
    let enc_owner = @cli.percent_encode_path_component(owner)
    let enc_repo = @cli.percent_encode_path_component(repo)
    let enc_tag = @cli.percent_encode_path_component(tag)
    url.set_pathname("/repos/\{enc_owner}/\{enc_repo}/releases/tags/\{enc_tag}")
    Ok(url.to_string())
  } catch {
    _ =>
      Err((0, "failed to build GitHub release URL for \{owner}/\{repo}@\{tag}"))
  }
}

///|
fn github_commit_url(
  owner : String,
  repo : String,
  sha : String,
) -> Result[String, (Int, String)] {
  try {
    let url = @url.Url::parse("https://api.github.com")
    let enc_owner = @cli.percent_encode_path_component(owner)
    let enc_repo = @cli.percent_encode_path_component(repo)
    let enc_sha = @cli.percent_encode_path_component(sha)
    url.set_pathname("/repos/\{enc_owner}/\{enc_repo}/git/commits/\{enc_sha}")
    Ok(url.to_string())
  } catch {
    _ =>
      Err((0, "failed to build GitHub commit URL for \{owner}/\{repo}@\{sha}"))
  }
}

///|
fn github_matching_refs_url(
  owner : String,
  repo : String,
  ref_type : String,
  prefix : String,
) -> Result[String, (Int, String)] {
  try {
    let url = @url.Url::parse("https://api.github.com")
    let enc_owner = @cli.percent_encode_path_component(owner)
    let enc_repo = @cli.percent_encode_path_component(repo)
    let enc_ref_type = @cli.percent_encode_path_component(ref_type)
    let enc_prefix = prefix
      .split("/")
      .map(fn(segment) {
        @cli.percent_encode_path_component(segment.to_owned())
      })
      .to_array()
      .join("/")
    url.set_pathname(
      "/repos/\{enc_owner}/\{enc_repo}/git/matching-refs/\{enc_ref_type}/\{enc_prefix}",
    )
    let params = @url.UrlSearchParams::new()
    params.set("per_page", "100")
    url.set_search_params(params)
    Ok(url.to_string())
  } catch {
    _ =>
      Err((0, "failed to build GitHub matching refs URL for \{owner}/\{repo}"))
  }
}

///|
priv suberror HttpError {
  HttpError((Int, String))
}

///|
fn github_headers() -> Map[String, String] {
  let headers = {
    "User-Agent": @papion.cli_user_agent(),
    "Accept": "application/vnd.github+json",
  }
  if github_token() is Some(token) {
    headers["Authorization"] = "Bearer \{token}"
  }
  headers
}

///|
fn[T] github_get(
  url : String,
  context : String,
  handle_response : (Int, String, String) -> Result[T, (Int, String)],
) -> Result[T, (Int, String)] {
  let mut result : Result[T, (Int, String)] = Err(
    (0, "request was not executed"),
  )
  @async.run_async_main(() => {
    let headers = github_headers()
    let request : Result[T, (Int, String)] = try {
      let value = @async.retry(
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
          match handle_response(response.code, response.reason, body.text()) {
            Ok(value) => value
            Err(err) => raise HttpError(err)
          }
        },
      )
      Ok(value)
    } catch {
      HttpError(err) => Err(err)
      err => Err((0, "\{context}: \{err}"))
    }
    match request {
      Ok(value) => result = Ok(value)
      Err(err) => result = Err(err)
    }
  })
  result
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
  github_get(url, "failed to fetch \{filename} from GitHub", fn(
    code,
    reason,
    body,
  ) {
    if code == 200 {
      extract_content_field(body, filename)
    } else {
      Err((code, "failed to fetch \{filename} from GitHub (\{code} \{reason})"))
    }
  })
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
  github_get(url, "failed to fetch repository metadata for \{owner}/\{repo}", fn(
    code,
    reason,
    body,
  ) {
    if code == 200 {
      extract_default_branch_field(body, owner, repo)
    } else {
      Err(
        (
          code,
          "failed to fetch repository metadata for \{owner}/\{repo} (\{code} \{reason})",
        ),
      )
    }
  })
}

///|
fn fetch_release_by_tag(
  owner : String,
  repo : String,
  tag : String,
) -> Result[Bool, (Int, String)] {
  let url = match github_release_by_tag_url(owner, repo, tag) {
    Ok(url) => url
    Err(err) => return Err(err)
  }
  github_get(
    url,
    "failed to fetch release metadata for \{owner}/\{repo}@\{tag}",
    fn(code, reason, body) {
      match code {
        200 => extract_release_immutable_field(body, owner, repo, tag)
        404 => Ok(false)
        _ =>
          Err(
            (
              code,
              "failed to fetch release metadata for \{owner}/\{repo}@\{tag} (\{code} \{reason})",
            ),
          )
      }
    },
  )
}

///|
fn fetch_commit_exists(
  owner : String,
  repo : String,
  sha : String,
) -> Result[Bool, (Int, String)] {
  let url = match github_commit_url(owner, repo, sha) {
    Ok(url) => url
    Err(err) => return Err(err)
  }
  github_get(url, "failed to verify commit SHA for \{owner}/\{repo}@\{sha}", fn(
    code,
    reason,
    _body,
  ) {
    match code {
      200 => Ok(true)
      404 => Ok(false)
      _ =>
        Err(
          (
            code,
            "failed to verify commit SHA for \{owner}/\{repo}@\{sha} (\{code} \{reason})",
          ),
        )
    }
  })
}

///|
fn fetch_matching_refs(
  owner : String,
  repo : String,
  ref_type : String,
  prefix : String,
) -> Result[Array[String], (Int, String)] {
  let url = match github_matching_refs_url(owner, repo, ref_type, prefix) {
    Ok(url) => url
    Err(err) => return Err(err)
  }
  github_get(url, "failed to fetch matching refs for \{owner}/\{repo}", fn(
    code,
    reason,
    body,
  ) {
    if code == 200 {
      extract_matching_refs_field(body, owner, repo, ref_type)
    } else {
      Err(
        (
          code,
          "failed to fetch matching refs for \{owner}/\{repo} (\{code} \{reason})",
        ),
      )
    }
  })
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
fn canonical_action_path(path : String?) -> String? {
  let normalized = normalize_action_path(path)
  if normalized.is_empty() {
    None
  } else {
    Some(normalized[0:normalized.length() - 1].to_owned())
  }
}

///|
fn select_best_matching_ref(
  candidates : Array[String],
  ref_prefix : String,
  path : String?,
) -> Result[(String, String?), String] {
  let full_path = match path {
    Some(path_value) if !path_value.is_empty() => "\{ref_prefix}/\{path_value}"
    _ => ref_prefix
  }
  let normalized_full_path = full_path
    .split("/")
    .filter(fn(segment) { !segment.is_empty() })
    .map(fn(segment) { segment.to_owned() })
    .to_array()
    .join("/")
  let mut best_ref : String? = None
  for candidate_ref in candidates {
    if normalized_full_path == candidate_ref ||
      normalized_full_path.has_prefix(candidate_ref + "/") {
      match best_ref {
        Some(current) if current.length() >= candidate_ref.length() => ()
        _ => best_ref = Some(candidate_ref)
      }
    }
  }
  let resolved_ref = match best_ref {
    Some(ref_name) => ref_name
    None => return Err("no matching Git refs found")
  }
  let remaining = if normalized_full_path.length() == resolved_ref.length() {
    None
  } else {
    let suffix = normalized_full_path[resolved_ref.length() + 1:].to_owned()
    if suffix.is_empty() {
      None
    } else {
      Some(suffix)
    }
  }
  Ok((resolved_ref, remaining))
}

///|
fn resolve_matching_ref(
  owner : String,
  repo : String,
  ref_prefix : String,
  path : String?,
) -> Result[(String, String?), (Int, String)] {
  let head_refs = match fetch_matching_refs(owner, repo, "heads", ref_prefix) {
    Ok(refs) => refs
    Err((404, _)) => []
    Err(err) => return Err(err)
  }
  let tag_refs = match fetch_matching_refs(owner, repo, "tags", ref_prefix) {
    Ok(refs) => refs
    Err((404, _)) => []
    Err(err) => return Err(err)
  }
  let candidates : Array[String] = []
  for ref_name in head_refs {
    candidates.push(ref_name)
  }
  for ref_name in tag_refs {
    candidates.push(ref_name)
  }
  match select_best_matching_ref(candidates, ref_prefix, path) {
    Ok(result) => Ok(result)
    Err(_) =>
      return Err(
        (
          404,
          "no matching Git refs found for \{owner}/\{repo} with prefix \{ref_prefix}",
        ),
      )
  }
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
) -> Result[(Bytes, String, String?), (Int, String)] {
  match try_fetch_action_yml(owner, repo, git_ref, path) {
    Ok(bytes) => Ok((bytes, git_ref, canonical_action_path(path)))
    Err((404, message)) => {
      if !allow_ref_fallback || path is None {
        return Err((404, message))
      }
      match resolve_matching_ref(owner, repo, git_ref, path) {
        Ok((resolved_ref, resolved_path)) =>
          match try_fetch_action_yml(owner, repo, resolved_ref, resolved_path) {
            Ok(bytes) =>
              Ok((bytes, resolved_ref, canonical_action_path(resolved_path)))
            Err(err) => Err(err)
          }
        Err((404, _)) => Err((404, message))
        Err(err) => Err(err)
      }
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
) -> Result[(String, String, String?), String] {
  let requested_git_ref = match git_ref {
    Some(git_ref) => git_ref
    None =>
      match fetch_default_branch(owner, repo) {
        Ok(branch) => branch
        Err((_, err)) => return Err(err)
      }
  }
  let (bytes, resolved_git_ref, resolved_path) = match
    fetch_action_yml_with_fallback(
      owner, repo, requested_git_ref, path, allow_ref_fallback,
    ) {
    Ok(result) => result
    Err((_, err)) => return Err(err)
  }
  let action_yml = try? @utf8.decode(bytes)
  match action_yml {
    Ok(action_yml) => Ok((action_yml, resolved_git_ref, resolved_path))
    Err(_) => Err("GitHub action file is not valid UTF-8")
  }
}

///|
fn resolve_ref_kind_impl(
  git_ref : String,
  commit_exists : (String, String, String) -> Result[Bool, (Int, String)],
  release_immutable : (String, String, String) -> Result[Bool, (Int, String)],
  owner : String,
  repo : String,
) -> @papion.RefKind {
  if @rules.classify_ref(git_ref) == Sha {
    match commit_exists(owner, repo, git_ref) {
      Ok(true) => return Sha
      _ => ()
    }
  }
  match release_immutable(owner, repo, git_ref) {
    Ok(true) => ImmutableRelease
    _ => Branch
  }
}

///|
pub fn resolve_ref_kind_via_api(
  owner : String,
  repo : String,
  git_ref : String,
) -> @papion.RefKind {
  resolve_ref_kind_impl(
    git_ref, fetch_commit_exists, fetch_release_by_tag, owner, repo,
  )
}

///|
fn cached_ref_kind_resolver_with(
  api : (String, String, String) -> @papion.RefKind,
) -> (String, String, String) -> @papion.RefKind {
  let cache : Map[String, @papion.RefKind] = {}
  fn(owner, repo, git_ref) {
    let key = "\{owner.to_lower()}/\{repo.to_lower()}@\{git_ref}"
    match cache.get(key) {
      Some(kind) => kind
      None => {
        let kind = api(owner, repo, git_ref)
        cache[key] = kind
        kind
      }
    }
  }
}

///|
fn cached_ref_kind_resolver() -> (String, String, String) -> @papion.RefKind {
  cached_ref_kind_resolver_with(resolve_ref_kind_via_api)
}
