# Org Policy (v2) is unavailable in this project: cge-p-capstone is a
# standalone GCP project with no Organization or Folder above it (confirmed
# via `gcloud projects get-ancestors` — ancestry is the project itself only).
# The account holds roles/owner, ruling out an IAM role gap; the actual
# failure is IAM_PERMISSION_DENIED on orgpolicy.policies.create, which
# requires a resource hierarchy context that an orgless project does not
# have. A Google Workspace / Cloud Identity account tied to a verified
# domain would be needed to attach an Organization and unlock this.
# Full evidence: evidence/lab-5-4/org-policy-restriction.txt
#
# Left commented out, same treatment given to a blocked service elsewhere
# in this capstone (see Lab 5.2's Security Hub restriction) — the
# restriction itself, independently confirmed rather than assumed, is
# the evidence.

# resource "google_org_policy_policy" "uniform_bucket_access" {
#   name   = "projects/${var.gcp_project}/policies/storage.uniformBucketLevelAccess"
#   parent = "projects/${var.gcp_project}"
#
#   spec {
#     rules {
#       enforce = "TRUE"
#     }
#   }
# }

# resource "google_org_policy_policy" "disable_sa_keys" {
#   name   = "projects/${var.gcp_project}/policies/iam.disableServiceAccountKeyCreation"
#   parent = "projects/${var.gcp_project}"
#
#   spec {
#     rules {
#       enforce = "TRUE"
#     }
#   }
# }
#
# resource "google_org_policy_policy" "require_oslogin" {
#   name   = "projects/${var.gcp_project}/policies/compute.requireOsLogin"
#   parent = "projects/${var.gcp_project}"
#
#   spec {
#     rules {
#       enforce = "TRUE"
#     }
#   }
# }
