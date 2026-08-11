# Lab 6.1 — OSCAL: Machine-Readable Compliance Documentation

This is the graph an auditor traverses without ever talking to you: catalog to profile to component to evidence URI to signed object in the vault. Everything below was built with NIST's compliance-trestle toolkit and validated by trestle's own schema validator, not just checked as well-formed JSON.

## What's here

| File | Model | Describes |
|---|---|---|
| component-definitions/compliant-s3-v1/component-definition.json | Component Definition | The compliant-s3 Terraform module (Lab 2.3), its four implemented NIST 800-53 controls, and the Terraform resource + evidence URI backing each one |
| profiles/cge-p-minimum/profile.json | Profile | Selects sc-28, ac-3, au-3, cm-6 from the NIST 800-53 Rev 5 catalog |
| catalogs/cge-p-minimum-resolved/catalog.json | Resolved catalog | The flattened output of resolving the profile against the live NIST catalog (trestle author profile-resolve) |

## The traversal, demonstrated

Each of the four implemented-requirements in the component definition (sc-28, ac-3, au-3, cm-6) links to the same evidence bundle: a real, signed pipeline run from the grc-gate CI pipeline (Lab 4.3/4.4), currently run 31520511303. Running scripts/verify-evidence.sh 31520511303 against that link returns CHAIN INTACT — integrity (SHA-256), authenticity (Cosign + Rekor), and preservation (Object Lock retention) all confirmed. An assessor reading this OSCAL document can verify the control without needing anything from me beyond the repo and the vault.

Note: the evidence URI documents the pipeline pattern rather than pointing at a single permanent artifact. The grc-gate pipeline produces a fresh signed bundle on every PR (Lab 4.4); the link above reflects the freshest verified bundle as of this lab, not a fixed pointer.

## Validation, run for real

trestle validate returned VALID for both the component definition and the profile. trestle author profile-resolve fetched the live NIST 800-53 Rev 5 catalog from GitHub and resolved it against the profile's control selection, producing a 68,953-byte resolved catalog containing exactly the four selected controls. Full output captured in evidence/lab-6-1/trestle-validate.txt.

## Path

oscal/component-definitions/compliant-s3-v1/component-definition.json
oscal/profiles/cge-p-minimum/profile.json
oscal/catalogs/cge-p-minimum-resolved/catalog.json

## Evidence

evidence/lab-6-1/trestle-validate.txt
