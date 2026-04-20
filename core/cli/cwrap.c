#include <stdint.h>
#include <string.h>

#include "moonbit.h"

static moonbit_bytes_t papion_make_bytes_from_cstr(const char *s) {
  size_t len = strlen(s);
  moonbit_bytes_t out = moonbit_make_bytes_raw((int32_t)len);
  if (len > 0) {
    memcpy(out, s, len);
  }
  return out;
}

moonbit_bytes_t papion_fetch_tarball(
  moonbit_bytes_t owner,
  moonbit_bytes_t repo,
  moonbit_bytes_t git_ref
) {
  (void)owner;
  (void)repo;
  (void)git_ref;
  return moonbit_make_bytes(0, 0);
}

moonbit_bytes_t papion_extract_action_yml(
  moonbit_bytes_t tarball,
  moonbit_bytes_t path
) {
  (void)tarball;
  (void)path;
  return moonbit_make_bytes(0, 0);
}

moonbit_bytes_t papion_load_config_json(moonbit_bytes_t path) {
  (void)path;
  return papion_make_bytes_from_cstr("{}");
}
