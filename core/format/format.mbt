///|
fn level_label(level : @papion.FindingLevel) -> String {
  match level {
    Warn => "WARN"
    Fail => "FAIL"
  }
}

///|
fn level_lower(level : @papion.FindingLevel) -> String {
  match level {
    Warn => "warn"
    Fail => "fail"
  }
}

///|
fn plural(n : Int, singular : String, plural_form : String) -> String {
  if n == 1 {
    singular
  } else {
    plural_form
  }
}

///|
/// Format a ScanResult as human-readable text.
///
/// Each finding shows WARN/FAIL label, target (with optional context), message,
/// and optional suggestion. Findings separated by blank lines.
/// Summary line uses singular/plural: "N finding/findings  (F failure/failures, W warning/warnings)".
/// Zero findings produces "No findings".
pub fn format_human(result : @papion.ScanResult) -> String {
  if result.findings.is_empty() {
    return "No findings"
  }
  let buf = StringBuilder::new()
  let mut first = true
  for finding in result.findings {
    if !first {
      buf.write_string("\n\n")
    }
    first = false
    let target_line = if finding.context is Some(ctx) {
      finding.target + " (" + ctx + ")"
    } else {
      finding.target
    }
    buf.write_string("  ")
    buf.write_string(level_label(finding.level))
    buf.write_string("  ")
    buf.write_string(target_line)
    buf.write_string("\n        ")
    buf.write_string(finding.message)
    if finding.suggestion is Some(s) {
      buf.write_string("\n        Tip: ")
      buf.write_string(s)
    }
  }
  let f = result.summary.failures
  let w = result.summary.warnings
  let n = result.findings.length()
  buf.write_string("\n\n")
  buf.write_string(n.to_string())
  buf.write_string(" ")
  buf.write_string(plural(n, "finding", "findings"))
  buf.write_string("  (")
  buf.write_string(f.to_string())
  buf.write_string(" ")
  buf.write_string(plural(f, "failure", "failures"))
  buf.write_string(", ")
  buf.write_string(w.to_string())
  buf.write_string(" ")
  buf.write_string(plural(w, "warning", "warnings"))
  buf.write_string(")")
  buf.to_string()
}

///|
fn finding_to_json(f : @papion.Finding) -> Json {
  let obj : Map[String, Json] = {
    "level": Json::string(level_lower(f.level)),
    "rule": Json::string(f.rule),
    "target": Json::string(f.target),
    "message": Json::string(f.message),
  }
  if f.context is Some(ctx) {
    obj["context"] = Json::string(ctx)
  }
  if f.suggestion is Some(s) {
    obj["suggestion"] = Json::string(s)
  }
  Json::object(obj)
}

///|
/// Format a ScanResult as JSON.
///
/// Target is serialized as a stable string: "owner/repo@ref" for GitHub or "local:<path>" for local.
/// Level values are lowercase ("warn"/"fail").
/// The top-level `ref` field contains the resolved target ref (GitHub scans only).
/// Optional finding fields (context, suggestion) are omitted when absent.
pub fn format_json(result : @papion.ScanResult) -> String {
  let root : Map[String, Json] = {
    "target": Json::string(result.target.format_target()),
    "findings": Json::array(result.findings.map(finding_to_json)),
    "summary": Json::object({
      "failures": Json::number(result.summary.failures.to_double()),
      "warnings": Json::number(result.summary.warnings.to_double()),
    }),
  }
  match result.target {
    @papion.GitHub({ git_ref, .. }) => root["ref"] = Json::string(git_ref)
    @papion.Local(_) => ()
  }
  Json::object(root).stringify()
}
