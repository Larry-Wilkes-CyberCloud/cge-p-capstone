# Compliance Policies (Rego / OPA / Conftest)

Rego policies that evaluate `terraform plan -json` output against NIST 800-53 controls, before anything applies. Each policy carries structured metadata mapping the rule to a specific control, severity, and remediation. Control IDs are portable across clouds; resource-type checks are not — each cloud gets its own variant.

## GCP policies (Lab 3.3)

| Control | File | Severity | Enforces |
|---|---|---|---|
| SC-28 | `sc28_encryption.rego` | High | Every `google_storage_bucket` has an `encryption { default_kms_key_name }` block |
| AC-3 | `ac3_no_public.rego` | Critical | Buckets enforce uniform access + public access prevention; firewalls don't expose ports 22/3389 to `0.0.0.0/0` |
| CM-6 | `cm6_required_tags.rego` | Medium | Every taggable resource carries all four required labels: `project`, `environment`, `managed_by`, `compliance_scope` |

## AWS policies (Lab 3.4)

| Control | File | Severity | Enforces |
|---|---|---|---|
| SC-28 | `sc28_encryption_aws.rego` | High | Every `aws_s3_bucket` has a matching `aws_s3_bucket_server_side_encryption_configuration` referencing it |
| AC-3 | `ac3_no_public_aws.rego` | Critical | Every `aws_s3_bucket` has a matching `aws_s3_bucket_public_access_block` with all four flags set true |
| CM-6 | `cm6_required_tags_aws.rego` | Medium | Every taggable AWS resource carries all four required tags: `Project`, `Environment`, `ManagedBy`, `ComplianceScope` |

Same three control IDs, six files, two clouds. The AWS variants match resources by Terraform configuration *references* (e.g. `aws_s3_bucket.primary.id`) rather than by literal planned value, since resource IDs are unresolved (`(known after apply)`) at plan time.

## Running the unit test suite

```bash
opa test -v policies/
```

## Evaluating against a real plan (OPA)

```bash
opa eval -d policies -i <path-to-plan.json> data.compliance.sc28.deny --format=pretty
```

## Evaluating against a real plan (Conftest)

```bash
conftest test --policy policies --namespace compliance.sc28_aws <path-to-plan.json>
```

An empty/passing result means no violations for that control.

## The policy gate script

`scripts/policy-gate.sh --workspace <path>` runs all four AWS/cross-cloud namespaces (`sc28_aws`, `ac3_aws`, `cm6_aws`, `cm6`) against a Terraform workspace's plan, writes combined JSON results to `evidence/lab-3-4/conftest-results.json`, and exits non-zero if anything fails — the exact script CI calls on every pull request.

## Test fixtures

- `lab-3-3-fixture/` — GCP fixture: one compliant bucket, three deliberately non-compliant resources, plus an open-SSH firewall rule.
- `primitives/compliant-s3/` (Lab 2.3) — the compliant AWS baseline used by the AWS variants.
- `broken/` (Lab 3.4) — a deliberately broken copy of the Lab 2.3 workspace with its `aws_s3_bucket_server_side_encryption_configuration` resource removed, used to prove the gate fails closed.
