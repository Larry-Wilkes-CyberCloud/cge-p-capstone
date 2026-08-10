import json
import sys

with open("evidence/conftest-results.json") as f:
    d = json.load(f)

fails = sum(len(r.get("failures") or []) for results in d for r in results)
print(f"conftest failures: {fails}")
sys.exit(0 if fails == 0 else 1)
