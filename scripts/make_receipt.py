#!/usr/bin/env python3
import sys
import json
from datetime import datetime, timezone

def main():
    if len(sys.argv) != 7:
        print("usage: make_receipt.py <run_id> <vault> <bundle_key> <version_id> <sha256> <commit>", file=sys.stderr)
        sys.exit(1)

    run_id, vault, bundle_key, version_id, sha256, commit = sys.argv[1:7]

    receipt = {
        "run_id": run_id,
        "vault_bucket": vault,
        "bundle_key": bundle_key,
        "s3_version_id": version_id,
        "sha256": sha256,
        "commit": commit,
        "signed_at": datetime.now(timezone.utc).isoformat(),
    }

    print(json.dumps(receipt, indent=2))

if __name__ == "__main__":
    main()
