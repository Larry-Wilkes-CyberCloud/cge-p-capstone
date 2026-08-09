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


## Lab 2.5 — Immutable Evidence Vault with Cryptographic Signing (Terraform, AWS)

A chain-of-custody layer for compliance evidence: an S3 vault that refuses deletion by design, and a capture script that hashes, bundles, and uploads evidence with a durable version pointer.

**What it enforces:**

- **S3 Object Lock**, enabled at bucket creation (cannot be retrofitted), in GOVERNANCE mode with a default retention period
- A **bucket policy denying `s3:DeleteBucket`** to anyone except the account root
- **Versioning + server-side encryption (AES256)** on every object
- **Public access fully blocked** at the bucket level

**Capture script (`scripts/capture-evidence.sh`):**

Pulls `plan.json`, `state.json`, git commit metadata, and Terraform version from a target workspace, computes a SHA-256 manifest of every file, bundles everything into a `.tar.gz`, uploads it to the vault, and prints a single-line JSON receipt (`run_id`, `vault`, `key`, `version_id`) for downstream pipelines to consume.

**Proof of immutability:** an object uploaded under active retention was deliberately targeted for deletion. AWS rejected it — `AccessDenied: Access Denied because object protected by object lock` — confirmed in `evidence/lab-2-5/deletion-denied-output.txt`.

**Stretch goal — cryptographic signing:** the evidence bundle was signed with Sigstore Cosign (keyless, OIDC-based) and independently re-verified against the original file, returning `Verified OK`. The signature and verification output are committed evidence: `evidence/lab-2-5/bundle.sig.bundle`, `evidence/lab-2-5/cosign-verify-output.txt`.

**Path:** `primitives/evidence-vault/`, `scripts/capture-evidence.sh`
**Evidence:** `evidence/lab-2-5/` (receipt.json, deletion-denied-output.txt, cosign-verify-output.txt, bundle.sig.bundle)

---


## Lab 3.3 — Compliance Policies in Rego (OPA, GCP)

Policy-as-code that evaluates a Terraform plan against NIST 800-53 controls before anything applies — turning `terraform plan -json` into the input for automated compliance gates.

**Policies:**

| Control | File | Severity | Enforces |
|---|---|---|---|
| SC-28 | `policies/sc28_encryption.rego` | High | Every `google_storage_bucket` has a CMEK `encryption` block |
| AC-3 | `policies/ac3_no_public.rego` | Critical | Buckets enforce uniform access + public access prevention; firewalls don't expose ports 22/3389 to `0.0.0.0/0` |
| CM-6 | `policies/cm6_required_tags.rego` | Medium | Every taggable resource carries all four required compliance labels |

Each policy carries a structured `# METADATA` block mapping the rule to its control ID, framework, severity, and remediation text — so a developer who trips a policy gets an actionable fix, not just a red X.

**Test fixture:** `lab-3-3-fixture/` — one fully compliant GCS bucket and three deliberately non-compliant resources, each engineered to trip exactly one policy (missing CMEK, public access, missing labels), plus an open-SSH firewall rule.

**Verified:**
- `opa test -v policies/` → 8/8 tests passing (unit tests per policy, both compliant and non-compliant fixtures)
- `opa eval` against the real `plan.json` correctly isolates each violation — SC-28 caught only the no-CMEK bucket, AC-3 caught the public bucket and the open firewall, CM-6 caught the no-labels bucket with all four missing labels listed
- The compliant `good` bucket triggered zero violations across all three policies

**Path:** `policies/`, `lab-3-3-fixture/`
**Evidence:** `evidence/lab-3-3/opa-test-results.json`
