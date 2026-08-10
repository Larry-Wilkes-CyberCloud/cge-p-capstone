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


## Lab 3.4 — Integrating Policy-as-Code with Terraform via Conftest (AWS)

Extends the Lab 3.3 policy library with AWS-typed variants, proving the same NIST 800-53 control IDs survive a cloud change even though the underlying resource types don't. Wires policy evaluation into a fail-closed gate script.

**AWS policy variants added:**

| Control | File | Enforces |
|---|---|---|
| SC-28 | `policies/sc28_encryption_aws.rego` | Every `aws_s3_bucket` has a matching `aws_s3_bucket_server_side_encryption_configuration` |
| AC-3 | `policies/ac3_no_public_aws.rego` | Every `aws_s3_bucket` has a matching `aws_s3_bucket_public_access_block` with all four flags true |
| CM-6 | `policies/cm6_required_tags_aws.rego` | Every taggable AWS resource carries all four required tags |

**The cross-cloud lesson, proven empirically:** running the original GCP-typed policies against an AWS plan produced false-positive passes — zero GCP resources meant zero violations, not real compliance. Adding cloud-specific variants (matched by Terraform configuration references, since resource IDs are unresolved at plan time) closed that gap.

**The policy gate script (`scripts/policy-gate.sh`):** runs all AWS/cross-cloud namespaces against a workspace's plan, writes combined JSON evidence, and exits non-zero on any failure — the exact script a CI pipeline calls on every pull request.

**Proof of a fail-closed gate:** a deliberately broken copy of the Lab 2.3 workspace (missing its S3 encryption configuration) was fed through the gate. Result: `policy-gate: FAIL`, non-zero exit, and a deny message naming the exact resource and remediation. The compliant original still passes clean.

**Path:** `policies/` (AWS variants), `scripts/policy-gate.sh`
**Evidence:** `evidence/lab-3-4/` (conftest-pass.json, conftest-fail.json, conftest-results.json)

## Lab 4.3 — Building a GRC Evidence Pipeline (AWS + GitHub Actions)

Wires the Lab 3.4 policy gate into GitHub Actions, running it on every pull request with AWS OIDC federation — no long-lived credentials stored anywhere. The workflow file itself is the evidence: `.github/workflows/grc-gate.yml` maps directly to CM-3, CM-6, CA-2, CA-7, RA-5, and AU-9.

**Infrastructure:**

| Piece | Path | Purpose |
|---|---|---|
| OIDC trust module | `oidc/` | Creates the AWS IAM OIDC provider + a repo-scoped IAM role, so GitHub Actions can assume AWS credentials without storing keys |
| CI workflow | `.github/workflows/grc-gate.yml` | Runs on every PR: Terraform plan → Conftest policy gate → tfsec scan → evidence artifact upload |
| tfsec suppression | `.tfsec/config.yml` | One documented suppression (AES256 vs CMEK — an intentional Lab 2.3 scoping decision, not a hidden gap), everything else must pass clean |
| Check scripts | `scripts/check_conftest_results.py`, `scripts/check_tfsec_results.py` | Parse tool output and decide pass/fail — pulled out of the workflow YAML for reliability |

**A real debugging story worth noting:** the initial OIDC setup failed with `Not authorized to perform sts:AssumeRoleWithWebIdentity` despite a syntactically correct trust policy. Root cause, found by decoding the actual OIDC token in a debug step: GitHub now embeds immutable numeric org/repo IDs into the subject claim (`repo:ORG@ORG_ID/REPO@REPO_ID:pull_request`), not just plain names — a security hardening measure most reference docs haven't caught up to yet. Fixed by matching the trust policy against the real claim format.

**Real findings caught along the way, not staged ones:** the initial clean run surfaced a genuine tfsec gap — the log bucket was missing versioning. Fixed for real (not suppressed). A second finding (AES256 vs customer-managed KMS on the primary bucket) was a deliberate Lab 2.3 scoping choice, documented and suppressed with a written justification rather than silently ignored.

**Red/green PR demonstration:** PR #2 deliberately weakened the primary bucket's public access block (`block_public_acls = false`). Both Conftest (AC-3) and tfsec independently caught it — the PR's own workflow run went from failure to success within the same PR's history once reverted, proving the gate blocks a real violation and passes a real fix.

**Path:** `oidc/`, `.github/workflows/grc-gate.yml`, `.tfsec/config.yml`, `scripts/check_conftest_results.py`, `scripts/check_tfsec_results.py`
**Evidence:** GitHub Actions run history — [green baseline run](https://github.com/Larry-Wilkes-CyberCloud/cge-p-capstone/actions/runs/31413586536), PR #2's red→green history, `grc-evidence-<run-id>` artifacts attached to every run (plan.json, conftest-results.json, tfsec.sarif, plan.txt)
