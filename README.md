# compliant-gcs-bucket

A Terraform module that provisions a Google Cloud Storage bucket with a hardcoded security and compliance floor. Consumers can change business configuration (environment, retention period, naming), but cannot disable, weaken, or opt out of any control enforced inside the module.

## What this module enforces

| Control | NIST 800-53 requirement | How it's enforced |
|---|---|---|
| **SC-12** | Cryptographic Key Establishment and Management | The module provisions and owns its own `google_kms_key_ring` and `google_kms_crypto_key` rather than relying on Google-managed default encryption. Key lifecycle is fully under this module's control. |
| **SC-13** | Cryptographic Protection | The bucket's `encryption.default_kms_key_name` is bound to the module-owned CMEK, not left to bucket defaults. Encryption is applied via approved cryptography (Google Cloud KMS), not optional. |
| **SC-28** | Protection of Information at Rest | All objects written to the bucket are encrypted at rest using the CMEK, with a 90-day (`7776000s`) automatic key rotation period, hardcoded in `main.tf` and not exposed as a variable. |
| **AU-11** | Audit Record Retention | `retention_policy.retention_period` is set from `var.retention_days`, with validation requiring `>= 365` days whenever `environment == "prod"`. Retention cannot be set below the compliant floor for production. |
| **CM-6** | Configuration Settings | Four required labels (`project`, `environment`, `managed_by`, `compliance_scope`) are defined in `locals.required_labels` and merged **on top of** any consumer-supplied labels, so they cannot be overridden or omitted. `uniform_bucket_level_access = true` and `public_access_prevention = "enforced"` are hardcoded baseline settings, not variables. |

## Interface

**Inputs consumers can set** (`variables.tf`):
- `gcp_project` – GCP project ID
- `location` – bucket location (supports multi-region, e.g. `US`)
- `kms_location` – KMS keyring location (single-region only, e.g. `us-central1`)
- `project_label` – short project identifier (validated: lowercase, 3–21 chars)
- `environment` – one of `dev`, `staging`, `prod`
- `retention_days` – 1–3650, but `>= 365` enforced when `environment == "prod"`
- `bucket_name_suffix` – globally-unique suffix for bucket/keyring/key naming
- `labels` – optional additional labels (compliance labels are always merged on top)

**What consumers cannot change:**
- Encryption algorithm or key ownership (SC-13/SC-28)
- Key rotation period (SC-12)
- Uniform bucket-level access or public access prevention (AC-3)
- The four required compliance labels (CM-6)
- The production retention floor of 365 days (AU-11)

**Outputs** (`outputs.tf`):
- `bucket_url` – `gs://` URL of the bucket
- `bucket_self_link` – bucket self-link
- `kms_key_id` – resource ID of the CMEK protecting the bucket
- `compliance_attestation` – computed map asserting the state of every enforced control (encryption algorithm, versioning, public access prevention, uniform access, retention period, required-labels presence, KMS rotation period)

## Usage

```hcl
module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project        = "your-gcp-project"
  project_label      = "cgep-lab"
  environment        = "dev"
  retention_days     = 30
  bucket_name_suffix = "dev-data-001"
}

output "attestation" { value = module.data_bucket.compliance_attestation }
output "bucket_url"  { value = module.data_bucket.bucket_url }
```

Six lines of business configuration yield a bucket enforcing SC-12, SC-13, SC-28, AU-11, and CM-6 (plus AC-3 via uniform access and public access prevention).

## Evidence

The `compliance_attestation` output is the machine-readable evidence artifact for this module — captured via `terraform output -json compliance_attestation` and referenced by later labs (Ch 3 Rego policy checks, Ch 6 OSCAL component definitions).

## Negative test

A `retention_days < 365` value combined with `environment = "prod"` fails at `terraform plan`, before any resource is created, via a variable validation block — not a runtime API rejection. See `consumers/negative-test/` for the reproducible failure case.
