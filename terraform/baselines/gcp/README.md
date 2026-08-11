# Lab 5.4 — GCP Security Services Baseline

Deploys GCP's identity-first compliance backbone: Workload Identity Federation replacing service account keys, and Data Access audit logs turned on for the services that matter most. Org Policy was attempted and genuinely blocked by the project's structure, not skipped — the restriction is documented with real evidence below, the same posture Lab 5.2 took toward a blocked Security Hub.

## What's deployed

| Piece | Status | Controls | Evidence |
|---|---|---|---|
| Workload Identity Federation (pool, provider, service account, binding) | Deployed | Keyless federated auth (AWS-OIDC equivalent) | evidence/lab-5-4/wif-provider.txt |
| Data Access audit logs (Storage, KMS, IAM) | Deployed | AU-2 | evidence/lab-5-4/iam-policy.json |
| Org Policy (uniform bucket access, disable SA keys, require OS Login) | Blocked | CM-6, AC-2, AC-3 | evidence/lab-5-4/org-policy-restriction.txt |

## Workload Identity Federation — keyless GCP auth for CI

Pool github-actions, provider github, trusting only GitHub's OIDC issuer with an attribute_condition scoped to this exact repository: assertion.repository equals "Larry-Wilkes-CyberCloud/cge-p-capstone".

This is the actual repo, not the lab template's placeholder — without this condition, any public GitHub repo could impersonate the service account. Verified live via gcloud iam workload-identity-pools providers describe.

A demo workflow, .github/workflows/gcp-wif-demo.yml, authenticates to GCP with zero service account key files anywhere in the repo or GitHub Secrets — the OIDC token is minted at job start and expires automatically. Same security posture as the AWS OIDC pattern from Lab 4.3, different cloud.

## Data Access audit logs — off by default, the #1 GCP audit finding

storage.googleapis.com, cloudkms.googleapis.com, and iam.googleapis.com all had DATA_READ, DATA_WRITE, and ADMIN_READ logging enabled via google_project_iam_audit_config. These are off by default in every GCP project — enabling them is a one-line Terraform block per service, and it's the single most-cited gap in real GCP audits. Verified live via gcloud projects get-iam-policy, captured in full.

## Org Policy — genuinely blocked, not skipped

cge-p-capstone is a standalone GCP project with no Organization or Folder above it (confirmed via gcloud projects get-ancestors). The account holds roles/owner, ruling out an IAM role gap — the actual failure is IAM_PERMISSION_DENIED on orgpolicy.policies.create, which requires a resource hierarchy context that an orgless project does not have. A Google Workspace or Cloud Identity account tied to a verified domain would be needed to attach an Organization and unlock this.

Resources are left in org_policy.tf, fully commented out, with the restriction documented inline and the full error chain (ancestry, empty policy list, permission denial) captured as evidence.

## Path

terraform/baselines/gcp/ — main.tf, variables.tf, org_policy.tf (commented), wif.tf, audit_logs.tf, outputs.tf
.github/workflows/gcp-wif-demo.yml

## Evidence

evidence/lab-5-4/wif-provider.txt, evidence/lab-5-4/iam-policy.json, evidence/lab-5-4/org-policy-restriction.txt
