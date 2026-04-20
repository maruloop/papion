#include <stdint.h>
#include "moonbit.h"


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

