# backend.tf
#
# Intentionally empty "s3" backend - partial configuration, same pattern as
# the root project's backend.tf. The actual bucket/region/key values are
# supplied at init time with:
#
#   terraform init -backend-config=backend.hcl
#
# This config reuses the SAME state bucket the root project's bootstrap/
# creates (bootstrap/ must be applied first, from the sibling project, for
# that bucket to exist) but writes to its own key within it, so state is
# fully isolated per-config while still reusing already-provisioned backend
# infrastructure rather than standing up a second bucket just for this demo.
# Nothing here reads or depends on the root project's state or resources -
# only the bucket name is shared.
terraform {
  backend "s3" {}
}
