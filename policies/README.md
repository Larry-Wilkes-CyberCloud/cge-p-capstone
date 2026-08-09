# Compliance Policies (Rego / OPA)

Rego policies that evaluate `terraform plan -json` output against NIST 800-53 controls, before anything applies to GCP. Each policy carries structured metadata mapping the rule to a specific control, severity, and remediation.

| Control | File | Severity | Enforces | Remediation |
|---|---|---|---|---|
| SC-28 | `sc28_encryption.rego` | High | Every `google_storage_bucket` has an `encryption { default_kms_key_name }` block | Add an `encryption` block referencing a `google_kms_crypto_key` you control |
| AC-3 | `ac3_no_public.rego` | Critical | Buckets enforce `uniform_bucket_level_access=true` and `public_access_prevention="enforced"`; firewalls don't expose ports 22 or 3389 to `0.0.0.0/0` | Lock down bucket access settings; narrow firewall `source_ranges` or remove the rule |
| CM-6 | `cm6_required_tags.rego` | Medium | Every taggable resource carries all four required labels: `project`, `environment`, `managed_by`, `compliance_scope` | Add the missing labels listed in the deny message |

## Running the suite

```bash
opa test -v policies/
```

## Evaluating against a real plan

```bash
opa eval -d policies -i <path-to-plan.json> data.compliance.sc28.deny --format=pretty
opa eval -d policies -i <path-to-plan.json> data.compliance.ac3.deny  --format=pretty
opa eval -d policies -i <path-to-plan.json> data.compliance.cm6.deny  --format=pretty
```

An empty array means no violations for that control.

## Test fixture

`lab-3-3-fixture/` is a deliberately mixed GCP Terraform configuration — one fully compliant bucket, and three non-compliant resources, each engineered to trip exactly one policy. This isolates each rule's behavior and proves the library only fires on the specific violation it's designed to catch.
