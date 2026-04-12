///|
/// Parse a `uses:` string into an ActionRef.
///
/// Format: `owner/repo@ref` or `owner/repo/path...@ref`
pub fn parse_action_ref(uses : String) -> Result[@papion.ActionRef, String] {
  guard uses.find("@") is Some(at_idx) else {
    return Err("missing '@' in uses string: \"" + uses + "\"")
  }
  let before_at = uses[0:at_idx].to_string()
  let git_ref = uses[at_idx + 1:].to_string()
  guard !git_ref.is_empty() else {
    return Err("empty ref in uses string: \"" + uses + "\"")
  }
  guard before_at.find("/") is Some(slash1) else {
    return Err("invalid format in uses string: \"" + uses + "\"")
  }
  let owner = before_at[0:slash1].to_string()
  guard !owner.is_empty() else {
    return Err("empty owner in uses string: \"" + uses + "\"")
  }
  let rest = before_at[slash1 + 1:].to_string()
  let (repo, path) = match rest.find("/") {
    None => (rest, None)
    Some(slash2) => {
      let repo_str = rest[0:slash2].to_string()
      let path_str = rest[slash2 + 1:].to_string()
      (repo_str, Some(path_str))
    }
  }
  guard !repo.is_empty() else {
    return Err("empty repo in uses string: \"" + uses + "\"")
  }
  Ok({ owner, repo, git_ref, path })
}

///|
/// Parse action.yml content (as JSON string) into an ActionYml.
///
/// The host must convert YAML to JSON before passing to this function.
/// The JSON must preserve the original action.yml field names (e.g. `using`).
pub fn parse_action_yml(json_str : String) -> Result[@papion.ActionYml, String] {
  try {
    let json = @json.parse(json_str)
    action_yml_from_json(json)
  } catch {
    e => Err(e.to_string())
  }
}

///|
fn action_yml_from_json(json : Json) -> Result[@papion.ActionYml, String] {
  guard json is Object(obj) else {
    return Err("expected JSON object for ActionYml")
  }
  let name = match obj.get("name") {
    Some(String(s)) => s
    _ => return Err("missing or invalid 'name' field")
  }
  let description = match obj.get("description") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let runs = match obj.get("runs") {
    Some(runs_json) =>
      match runs_from_json(runs_json) {
        Ok(r) => r
        Err(e) => return Err(e)
      }
    _ => return Err("missing 'runs' field")
  }
  Ok({ name, description, runs })
}

///|
fn runs_from_json(json : Json) -> Result[@papion.Runs, String] {
  guard json is Object(obj) else { return Err("expected JSON object for runs") }
  let runner = match obj.get("using") {
    Some(String(s)) => s
    _ => return Err("missing or invalid 'using' field in runs")
  }
  let steps = match obj.get("steps") {
    Some(Array(arr)) => {
      let acc : Array[@papion.CompositeStep] = Array::new()
      for step_json in arr {
        match composite_step_from_json(step_json) {
          Ok(step) => acc.push(step)
          Err(e) => return Err(e)
        }
      }
      Some(acc)
    }
    _ => None
  }
  Ok({ runner, steps })
}

///|
fn composite_step_from_json(
  json : Json,
) -> Result[@papion.CompositeStep, String] {
  guard json is Object(obj) else { return Err("expected JSON object for step") }
  let uses = match obj.get("uses") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let run = match obj.get("run") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let name = match obj.get("name") {
    Some(String(s)) => Some(s)
    _ => None
  }
  Ok({ uses, run, name })
}

///|
/// Extract all action references from the `uses:` fields of composite steps.
///
/// Steps without `uses:` or with unparseable refs are silently skipped.
pub fn extract_refs(yml : @papion.ActionYml) -> Array[@papion.ActionRef] {
  let refs = Array::new()
  match yml.runs.steps {
    None => ()
    Some(steps) =>
      for step in steps {
        match step.uses {
          None => ()
          Some(uses_str) =>
            match parse_action_ref(uses_str) {
              Ok(r) => refs.push(r)
              Err(_) => ()
            }
        }
      }
  }
  refs
}
