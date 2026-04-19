///|
pub(all) struct ActionRef {
  owner : String
  repo : String
  git_ref : String
  path : String?
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for ActionRef with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) enum RefKind {
  Sha
  Tag
  Branch
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for RefKind with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct ActionYml {
  name : String
  description : String?
  runs : Runs
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for ActionYml with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct Runs {
  runner : String
  steps : Array[CompositeStep]?
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for Runs with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct CompositeStep {
  uses : String?
  run : String?
  name : String?
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for CompositeStep with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) enum FindingLevel {
  Warn
  Fail
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for FindingLevel with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct Finding {
  level : FindingLevel
  rule : String
  target : String
  context : String?
  message : String
  suggestion : String?
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for Finding with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct Policy {
  sha_pinning : Bool
  allowed : Array[String]
  disallowed : Array[String]
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for Policy with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub fn Policy::default() -> Policy {
  { sha_pinning: true, allowed: [], disallowed: [] }
}

///|
pub(all) struct ScanTarget {
  owner : String
  repo : String
  git_ref : String
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for ScanTarget with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct Summary {
  failures : Int
  warnings : Int
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for Summary with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}

///|
pub(all) struct ScanResult {
  target : ScanTarget
  findings : Array[Finding]
  summary : Summary
} derive(Debug, Eq, ToJson, FromJson)
pub impl Show for ScanResult with output(self, logger) {
  logger.write_string(self.to_json().stringify())
}
