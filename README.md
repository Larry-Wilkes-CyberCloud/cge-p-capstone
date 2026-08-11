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

## Lab 4.4 — Evidence Management & Chain of Custody (AWS)

Extends the Lab 4.3 pipeline so every CI run cryptographically signs its own evidence and ships it to a WORM-protected vault — turning "we ran a compliance check" into "here is provable, tamper-evident proof that we ran it, when, and that the result hasn't been altered since."

**What was added:**

| Piece | Path | Purpose |
|---|---|---|
| Bundle/sign/upload script | `scripts/bundle-sign-upload.sh` | Tars the run's evidence dir, computes its SHA-256, signs it with Cosign (keyless, via Sigstore/Fulcio), and uploads the bundle + checksum + signature + a JSON receipt to the vault |
| Receipt generator | `scripts/make_receipt.py` | Builds a structured receipt.json (run ID, vault key, S3 version ID, SHA-256, commit, signed-at timestamp) for every signed bundle |
| Verification script | `scripts/verify-evidence.sh` | Independently re-checks a vaulted bundle's integrity (SHA-256), authenticity (Cosign + Rekor transparency log), and preservation (Object Lock retention status) |
| CI workflow (restructured) | `.github/workflows/grc-gate.yml` | Conftest and tfsec no longer short-circuit the job on failure — evidence is bundled, signed, and uploaded to the vault on every run, and only the final gate-evaluation step decides pass/fail. This is deliberate: the point of chain of custody is that evidence survives even a failing run. |

**Cosign keyless signing, proven with a real transparency log entry:** each pipeline run signs its evidence bundle with an ephemeral Sigstore-issued certificate bound to the GitHub Actions OIDC identity, and the signature is recorded in the public Rekor log. Run `31419052889` (PR #3) produced Rekor transparency log index `2411325216`.

**The tamper test — a real before/after/restore cycle, not a staged one:**

1. `verify-evidence.sh` against the untouched vaulted bundle: `CHAIN INTACT for run 31419052889` (SHA-256 match, Cosign+Rekor verified, Object Lock retention active).
2. The vaulted object was deliberately overwritten in S3 with modified content. Because of Object Lock GOVERNANCE mode, this could not delete or replace the original — it only created a new object version.
3. Re-running `verify-evidence.sh` against the (now current) tampered version: `FAIL: SHA mismatch` — caught immediately, before signature or retention checks even ran.
4. The original, untouched version was still present underneath (protected by Object Lock) and was restored via `aws s3api copy-object` against its original version ID — its ETag matched the pre-tamper original exactly, confirming byte-for-byte preservation.
5. Re-running `verify-evidence.sh` one more time: `CHAIN INTACT for run 31419052889` again.

This demonstrates all four chain-of-custody properties with real evidence rather than a hypothetical: authenticity (Cosign/Rekor), integrity (SHA-256, both passing and correctly failing), timeliness (GitHub Actions + Rekor + receipt timestamps), and preservation (Object Lock survived an actual overwrite attempt). Full mapping in [WRITEUP.md](./WRITEUP.md).

**Path:** `primitives/evidence-vault/`, `scripts/bundle-sign-upload.sh`, `scripts/make_receipt.py`, `scripts/verify-evidence.sh`, `.github/workflows/grc-gate.yml`
**Evidence:** [PR #3](https://github.com/Larry-Wilkes-CyberCloud/cge-p-capstone/pull/3), [signing run 31419052889](https://github.com/Larry-Wilkes-CyberCloud/cge-p-capstone/actions/runs/31419052889), Rekor tlog index `2411325216`, [WRITEUP.md](./WRITEUP.md)

## Lab 5.2 — AWS Security Services Baseline

Deploys the AWS-native compliance backbone: CloudTrail for audit logging, with Security Hub and Config scoped out where the account genuinely restricts them. This lab is as much about proving what an account can and can't do as it is about deploying services — every scoping decision below is backed by a real, captured error, not an assumption.

**What was added:**

| Piece | Path | Purpose |
|---|---|---|
| CloudTrail (multi-region, log-file validation) | `terraform/baselines/aws/cloudtrail.tf` | Multi-region trail covering all regions and global service events, with enable_log_file_validation for AU-10 (audit integrity) |
| Security Hub (attempted, blocked) | `terraform/baselines/aws/security_hub.tf` | Confirmed genuinely account-blocked (SubscriptionRequiredException), not an IAM gap — verified via both terraform apply and a direct CLI call |
| AWS Config (not attempted) | `terraform/baselines/aws/config.tf` | Left commented out per the lab's own guidance |

**CloudTrail — AU-2, AU-12, AU-10:** deployed and verified live. `aws cloudtrail get-trail-status` returned IsLogging: true, with StartLoggingTime and LatestDeliveryTime both populated within minutes of apply.

**Security Hub — genuinely blocked, not skipped:** both `terraform apply` (via aws_securityhub_account) and a direct `aws securityhub enable-security-hub` call independently returned the same error: SubscriptionRequiredException — The AWS Access Key Id needs a subscription for the service. This is not an IAM permissions gap — the same credentials that deployed CloudTrail, oidc/, and the evidence vault in earlier labs hit this wall specifically on Security Hub, consistent with how some training/sandbox-provisioned AWS accounts restrict services requiring a full support/billing relationship. Rather than silently omitting it, the resources are left in security_hub.tf, fully commented out, with the restriction documented inline and the raw CLI error captured as evidence.

**Path:** `terraform/baselines/aws/` (main.tf, variables.tf, cloudtrail.tf, security_hub.tf commented, config.tf commented, outputs.tf)
**Evidence:** `evidence/lab-5-2/cloudtrail-status.json`, `evidence/lab-5-2/security-hub-restriction.txt`

## Lab 5.4 — GCP Security Services Baseline

Deploys GCP's identity-first compliance backbone: Workload Identity Federation replacing service account keys, and Data Access audit logs turned on for the services that matter most. Org Policy was attempted and genuinely blocked by the project's structure, not skipped — the restriction is documented with real evidence, the same posture Lab 5.2 took toward a blocked Security Hub.

**What was added:**

| Piece | Path | Purpose |
|---|---|---|
| Workload Identity Federation | `terraform/baselines/gcp/wif.tf` | Pool, provider, service account, and IAM binding — the provider's attribute_condition is scoped to this exact repo, not the lab template's placeholder |
| Data Access audit logs | `terraform/baselines/gcp/audit_logs.tf` | DATA_READ, DATA_WRITE, ADMIN_READ enabled for storage, KMS, and IAM services — off by default in every GCP project, the #1 cited GCP audit finding |
| Org Policy (attempted, blocked) | `terraform/baselines/gcp/org_policy.tf` | Confirmed structurally blocked: cge-p-capstone has no GCP Organization above it, verified via gcloud projects get-ancestors and an empty org-policies list |
| Demo workflow | `.github/workflows/gcp-wif-demo.yml` | Proves keyless GCP authentication end-to-end via workflow_dispatch |

**Live proof of keyless auth, not just a config:** the demo workflow was actually triggered and run. The job authenticated as `cgep-grc-gate-sa@cge-p-capstone.iam.gserviceaccount.com` with zero service account key files anywhere in the repo or GitHub Secrets — the OIDC-derived credential was written to a temp path at job start and explicitly removed at job end ("Removed exported credentials at ..."). Same security posture as the AWS OIDC pattern from Lab 4.3, different cloud.

**Org Policy — genuinely blocked, not skipped:** cge-p-capstone is a standalone GCP project with no Organization or Folder above it. The account holds roles/owner, ruling out an IAM role gap — the actual failure is IAM_PERMISSION_DENIED on orgpolicy.policies.create, which requires a resource hierarchy context an orgless project doesn't have. A Google Workspace or Cloud Identity account tied to a verified domain would be needed to unlock this. Resources are left in org_policy.tf, fully commented out, with the restriction documented inline and the full error chain captured as evidence.

**Path:** `terraform/baselines/gcp/` (main.tf, variables.tf, org_policy.tf commented, wif.tf, audit_logs.tf, outputs.tf), `.github/workflows/gcp-wif-demo.yml`
**Evidence:** `evidence/lab-5-4/wif-provider.txt`, `evidence/lab-5-4/iam-policy.json`, `evidence/lab-5-4/org-policy-restriction.txt`, `evidence/lab-5-4/wif-live-auth-proof.txt`, [live workflow run](https://github.com/Larry-Wilkes-CyberCloud/cge-p-capstone/actions/runs/31520675967)
