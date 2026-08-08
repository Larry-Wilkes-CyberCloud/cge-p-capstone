# CGE-P Capstone: Compliance-as-Code with Terraform

Hands-on labs building NIST 800-53-aligned cloud infrastructure with Terraform, across AWS and GCP. Each lab enforces its compliance controls in code — not as after-the-fact documentation — with machine-readable evidence captured at apply time.

---

## Lab 2.3 — Compliant S3 Bucket (Terraform, AWS)

A single Terraform-managed S3 bucket enforcing a hardcoded compliance floor.

**Controls enforced:**

| Control | NIST 800-53 requirement | Implementation |
|---|---|---|
| SC-28 | Protection of Information at Rest | Bucket encryption enforced via AES256 server-side encryption |
| AU-3 / AU-6 | Content of Audit Records / Audit Review | Logging bucket captures access logs for the data bucket |
| CM-6 | Configuration Settings | Versioning, public-access-block, and required tags hardcoded, not optional |
| AC-3 | Access Enforcement | Public access blocked at the bucket-policy level |

**Path:** `primitives/compliant-s3/`
**Evidence:** `evidence/lab-2-3/` (plan.json, state.json)

---

## Lab 2.4 — Compliant GCS Bucket Module (Terraform, GCP)

A reusable Terraform module that provisions a Google Cloud Storage bucket with a hardcoded security and compliance floor. Consumers can change business configuration (environment, retention period, naming), but cannot disable, weaken, or opt out of any control enforced inside the module.

**Controls enforced:**

| Control | NIST 800-53 requirement | Implementation |
|---|---|---|
| SC-12 | Cryptographic Key Establishment and Management | Module provisions and owns its own `google_kms_key_ring` and `google_kms_crypto_key`, not Google-managed default encryption |
| SC-13 | Cryptographic Protection | Bucket's `encryption.default_kms_key_name` bound to the module-owned CMEK |
| SC-28 | Protection of Information at Rest | CMEK encryption with 90-day (`7776000s`) automatic key rotation, hardcoded |
| AU-11 | Audit Record Retention | `retention_policy.retention_period` set from `var.retention_days`, validated `>= 365` days when `environment == "prod"` |
| CM-6 | Configuration Settings | Four required labels merged on top of consumer-supplied labels; `uniform_bucket_level_access` and `public_access_prevention` hardcoded |
| AC-3 | Access Enforcement | Uniform bucket-level access and enforced public access prevention, non-configurable |

**Interface:**

Inputs consumers can set: `gcp_project`, `location`, `kms_location`, `project_label`, `environment`, `retention_days`, `bucket_name_suffix`, `labels`.

What consumers cannot change: encryption/key ownership, key rotation period, uniform access/public prevention, required compliance labels, the 365-day production retention floor.

Outputs: `bucket_url`, `bucket_self_link`, `kms_key_id`, `compliance_attestation` (machine-readable evidence of every enforced control).

**Usage:**

```hcl
module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project        = "your-gcp-project"
  project_label      = "cgep-lab"
  environment        = "dev"
  retention_days     = 30
  bucket_name_suffix = "dev-data-001"
}
```

**Negative test:** a `retention_days < 365` value combined with `environment = "prod"` fails at `terraform plan`, before any resource is created, via variable validation — not a runtime API rejection. See `consumers/negative-test/`.

**Path:** `modules/compliant-gcs-bucket/`
**Evidence:** `evidence/lab-2-4/` (plan.json, attestation.json, negative-test-output.txt)

---

## Why this matters

Both labs demonstrate the same principle on two different clouds: compliance controls belong inside the infrastructure code itself, where a consumer physically cannot disable them, rather than in a wiki page someone forgets to update. The `compliance_attestation` outputs feed forward into later labs — Rego policy checks that block a merge without proof of compliance, and OSCAL evidence artifacts for formal audit packages.