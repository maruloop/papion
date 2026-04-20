///|
#borrow(owner, repo, git_ref)
extern "C" fn fetch_tarball_ffi(
  owner : Bytes,
  repo : Bytes,
  git_ref : Bytes,
) -> Bytes = "papion_fetch_tarball"

///|
pub fn fetch_tarball(
  owner : String,
  repo : String,
  git_ref : String,
) -> Result[Bytes, String] {
  let tarball = fetch_tarball_ffi(
    @utf8.encode(owner),
    @utf8.encode(repo),
    @utf8.encode(git_ref),
  )
  if tarball.length() == 0 {
    Err("GitHub tarball fetch is not implemented in WS6")
  } else {
    Ok(tarball)
  }
}
