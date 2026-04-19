///|
pub(all) struct ActionRef {
  owner : String
  repo : String
  git_ref : String
  path : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum RefKind {
  Sha
  Tag
  Branch
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ActionYml {
  name : String
  description : String?
  runs : Runs
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct Runs {
  runner : String
  steps : Array[CompositeStep]?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct CompositeStep {
  uses : String?
  run : String?
  name : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) enum FindingLevel {
  Warn
  Fail
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct Finding {
  level : FindingLevel
  rule : String
  target : String
  context : String?
  message : String
  suggestion : String?
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct Policy {
  sha_pinning : Bool
  allowed : Array[String]
  disallowed : Array[String]
} derive(Debug, Eq, ToJson, FromJson)

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

///|
pub(all) struct Summary {
  failures : Int
  warnings : Int
} derive(Debug, Eq, ToJson, FromJson)

///|
pub(all) struct ScanResult {
  target : ScanTarget
  findings : Array[Finding]
  summary : Summary
} derive(Debug, Eq, ToJson, FromJson)
