#!/usr/bin/env bash
#
# Fails the build on a critical advisory, and only on that.
#
# `npm audit` exits non-zero for two unrelated reasons: it found something, or it could not
# reach the registry's audit endpoint. The second is an npm outage, not a statement about this
# repo, and gating a deploy on it means a 503 upstream blocks a green commit from shipping.
# So the report is parsed instead of trusted by exit code: a transport error is a warning, a
# critical advisory is still a failure.
#
# wagmi pulls walletconnect transitive advisories that sit at moderate/high with none critical,
# which is why the threshold is critical rather than the npm default.
set -uo pipefail

report=$(mktemp)
trap 'rm -f "$report"' EXIT

for attempt in 1 2 3; do
  if npm audit --json >"$report" 2>/dev/null; then
    break
  fi
  # A populated report means npm reached the registry and has something to say; the retry is
  # only for the case where it came back empty or unparsable.
  if [ -s "$report" ] && python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$report" 2>/dev/null; then
    break
  fi
  if [ "$attempt" -lt 3 ]; then
    echo "npm audit did not return a usable report (attempt $attempt); retrying in 15s"
    sleep 15
  fi
done

python3 - "$report" <<'PY'
import json
import sys

try:
    with open(sys.argv[1]) as handle:
        report = json.load(handle)
except (OSError, ValueError):
    print("::warning::npm audit returned no parsable report; the advisory gate did not run")
    sys.exit(0)

error = report.get("error")
if error:
    detail = error.get("summary") or error.get("code") if isinstance(error, dict) else error
    print(f"::warning::npm audit endpoint unavailable ({detail}); the advisory gate did not run")
    sys.exit(0)

counts = report.get("metadata", {}).get("vulnerabilities", {})
summary = ", ".join(f"{level}: {counts.get(level, 0)}" for level in ("critical", "high", "moderate", "low", "info"))
print(f"npm audit advisories -> {summary}")

critical = counts.get("critical", 0)
if critical:
    print(f"::error::{critical} critical advisory(ies); see the report above")
    sys.exit(1)
PY
