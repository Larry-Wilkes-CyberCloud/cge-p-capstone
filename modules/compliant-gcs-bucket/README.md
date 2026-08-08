\# compliant-gcs-bucket



A Terraform module that deploys a NIST 800-53-aligned Google Cloud Storage bucket with customer-managed encryption. Consumers supply business config (environment, retention, naming); the module hardcodes the compliance floor.



\## Controls enforced



| Control | Family | Requirement | Implementation |

|---|---|---|---|

| SC-12 | System and Communications Protection | Cryptographic key establishment and management | Dedicated `google\_kms\_key\_ring` + `google\_kms\_crypto\_key` created and owned by this module, not Google-managed default encryption |

| SC-13 | System and Communications Protection | Use of cryptographic protection | Bucket's `encryption.default\_kms\_key\_name` is bound to the module-owned CMEK; no unencrypted or default-key path exists |

| SC-28 | System and Communications Protection | Protection of information at rest | Same CMEK binding as SC-13, plus 90-day (`7776000s`) mandatory key rotation via `rotation\_period` |

| AU-11 | Audit and Accountability | Audit record retention | `retention\_policy.retention\_period` set from `var.retention\_days`; validation blocks any `prod` deployment below 365 days |

| CM-6 | Configuration Management | Configuration settings | Four required labels (`project`, `environment`, `managed\_by`, `compliance\_scope`) merged on top of consumer-supplied labels in `locals.effective\_labels` — consumers can add labels but cannot remove or override the required set |

| AC-3 | Access Control | Access enforcement | `uniform\_bucket\_level\_access = true` and `public\_access\_prevention = "enforced"` are hardcoded, non-configurable |



\## Inputs



| Name | Type | Default | Description |

|---|---|---|---|

| `gcp\_project` | string | — | GCP project ID |

| `location` | string | `us-central1` | Bucket location (multi-region values like `US` allowed) |

| `kms\_location` | string | `us-central1` | Keyring location (single-region only) |

| `project\_label` | string | — | Short project identifier, 3-21 lowercase alphanumeric/hyphen |

| `environment` | string | — | One of `dev`, `staging`, `prod` |

| `retention\_days` | number | — | 1-3650; must be >= 365 when `environment = "prod"` |

| `bucket\_name\_suffix` | string | — | Globally-unique suffix, 3-30 lowercase alphanumeric/hyphen |

| `labels` | map(string) | `{}` | Optional additional labels merged under required compliance labels |



\## Outputs



| Name | Description |

|---|---|

| `bucket\_url` | `gs://` URL of the created bucket |

| `bucket\_self\_link` | Bucket self-link |

| `kms\_key\_id` | Resource ID of the CMEK protecting the bucket |

| `compliance\_attestation` | Computed map of control status — encryption algorithm, versioning, access prevention, retention, label presence, rotation period. Machine-readable evidence for downstream policy checks. |



\## Usage



```hcl

module "data\_bucket" {

&#x20; source = "../../modules/compliant-gcs-bucket"



&#x20; gcp\_project        = "your-gcp-project"

&#x20; project\_label      = "cgep-lab"

&#x20; environment        = "dev"

&#x20; retention\_days     = 30

&#x20; bucket\_name\_suffix = "dev-data-001"

}

```



\## Negative test



A consumer with `environment = "prod"` and `retention\_days < 365` fails at `terraform plan`, before any resource is created, via the cross-field validation rule in `variables.tf`. See `evidence/lab-2-4/negative-test-output.txt`.

