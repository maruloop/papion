///|
/// Parse a `uses:` string into an ActionRef.
///
/// Format: `owner/repo@ref` or `owner/repo/path...@ref`
pub fn parse_action_ref(uses : String) -> Result[@papion.ActionRef, String] {
  guard !uses.has_prefix("./") else {
    return Err("relative path action not supported: \"" + uses + "\"")
  }
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
      guard !path_str.is_empty() else {
        return Err("empty path in uses string: \"" + uses + "\"")
      }
      (repo_str, Some(path_str))
    }
  }
  guard !repo.is_empty() else {
    return Err("empty repo in uses string: \"" + uses + "\"")
  }
  Ok({ owner, repo, git_ref, path })
}

///|
/// Parse action.yml content (as YAML string) into an ActionYml.
pub fn parse_action_yml(yaml_str : String) -> Result[@papion.ActionYml, String] {
  let docs = @yaml.Yaml::load_from_string(yaml_str) catch {
    e => return Err(e.to_string())
  }
  match docs.length() {
    0 => return Err("empty YAML document")
    1 => ()
    _ => return Err("expected exactly one YAML document in action.yml")
  }
  action_yml_from_yaml(docs[0])
}

///|
// Coerce any YAML scalar to String. Boolean and Integer use MoonBit's
// canonical repr ("true"/"false", decimal) because the yaml library does
// not preserve the original source text for those variants (unlike Real,
// which carries repr~). This library follows YAML 1.2 semantics: bare
// "on"/"yes"/etc. remain strings, only "true"/"false" parse as booleans.
// Boolean coercion is therefore rare in practice but handled for safety.
fn yaml_scalar_to_string(yaml : @yaml.Yaml) -> String? {
  match yaml {
    String(s) => Some(s)
    Integer(n) => Some(n.to_string())
    Boolean(b) => Some(if b { "true" } else { "false" })
    Real(_, repr~) => Some(repr)
    _ => None
  }
}

///|
fn action_yml_from_yaml(yaml : @yaml.Yaml) -> Result[@papion.ActionYml, String] {
  guard yaml is Map(obj) else {
    return Err("expected YAML mapping for ActionYml")
  }
  let name = match obj.get("name") {
    Some(v) =>
      match yaml_scalar_to_string(v) {
        Some(s) => s
        None => return Err("missing or invalid 'name' field")
      }
    None => return Err("missing or invalid 'name' field")
  }
  let description = match obj.get("description") {
    Some(Null) | None => None
    Some(v) =>
      match yaml_scalar_to_string(v) {
        Some(s) => Some(s)
        None => return Err("invalid 'description' field: expected string")
      }
  }
  let runs = match obj.get("runs") {
    Some(runs_yaml) =>
      match runs_from_yaml(runs_yaml) {
        Ok(r) => r
        Err(e) => return Err(e)
      }
    _ => return Err("missing 'runs' field")
  }
  Ok({ name, description, runs })
}

///|
fn runs_from_yaml(yaml : @yaml.Yaml) -> Result[@papion.Runs, String] {
  guard yaml is Map(obj) else { return Err("expected YAML mapping for runs") }
  let runner = match obj.get("using") {
    Some(v) =>
      match yaml_scalar_to_string(v) {
        Some(s) => s
        None => return Err("missing or invalid 'using' field in runs")
      }
    None => return Err("missing or invalid 'using' field in runs")
  }
  let steps = match obj.get("steps") {
    None => None
    Some(Array(arr)) => {
      let acc : Array[@papion.CompositeStep] = Array::new()
      for step_yaml in arr {
        match composite_step_from_yaml(step_yaml) {
          Ok(step) => acc.push(step)
          Err(e) => return Err(e)
        }
      }
      Some(acc)
    }
    Some(_) => return Err("invalid 'steps' field: expected array")
  }
  Ok({ runner, steps })
}

///|
fn optional_yaml_string(
  obj : Map[String, @yaml.Yaml],
  field : String,
) -> Result[String?, String] {
  match obj.get(field) {
    None => Ok(None)
    Some(Null) => Err("invalid '" + field + "' field in step: expected string")
    Some(v) =>
      match yaml_scalar_to_string(v) {
        Some(s) => Ok(Some(s))
        None => Err("invalid '" + field + "' field in step: expected string")
      }
  }
}

///|
fn composite_step_from_yaml(
  yaml : @yaml.Yaml,
) -> Result[@papion.CompositeStep, String] {
  guard yaml is Map(obj) else { return Err("expected YAML mapping for step") }
  let uses = match optional_yaml_string(obj, "uses") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let run = match optional_yaml_string(obj, "run") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  let name = match optional_yaml_string(obj, "name") {
    Ok(v) => v
    Err(e) => return Err(e)
  }
  Ok({ uses, run, name })
}

///|
/// Extract all action references from the `uses:` fields of composite steps.
///
/// Best-effort: relative path steps (./path) and unparseable refs are silently
/// skipped. The caller receives all successfully parsed refs regardless of
/// partial failures. Returns an empty array for non-composite actions.
pub fn extract_refs(yml : @papion.ActionYml) -> Array[@papion.ActionRef] {
  let refs = Array::new()
  match yml.runs.steps {
    None => ()
    Some(steps) =>
      for step in steps {
        match step.uses {
          None => ()
          Some(uses_str) =>
            if !uses_str.has_prefix("./") {
              match parse_action_ref(uses_str) {
                Ok(r) => refs.push(r)
                Err(_) => ()
              }
            }
        }
      }
  }
  refs
}
