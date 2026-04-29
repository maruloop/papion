///|
pub fn fetch_action_yml(
  _owner : String,
  _repo : String,
  _git_ref : String?,
  _path : String?,
  _allow_ref_fallback : Bool,
) -> Result[(String, String, String?), String] {
  Err("GitHub action fetch is not available on WASM targets")
}
