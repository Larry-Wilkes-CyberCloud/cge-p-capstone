import json
import sys

with open("evidence/tfsec.sarif") as f:
    d = json.load(f)

high = sum(
    1
    for run in d.get("runs", [])
    for r in run.get("results", [])
    if (r.get("level") or "").lower() in ("error", "critical", "high")
)
print(f"tfsec high+critical: {high}")
sys.exit(0 if high == 0 else 1)
