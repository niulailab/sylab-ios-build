#!/bin/bash
set -euo pipefail
cd /root/sylab-app
cp -a package.json package.json.bak_v140
cp -a app.json app.json.bak_v140
sed -i 's/"version": "1.0.15"/"version": "1.0.16"/' package.json
sed -i 's/"version": "1.0.15"/"version": "1.0.16"/' app.json
sed -i 's/"buildNumber": "15"/"buildNumber": "16"/' app.json
echo "=== verify ==="
grep '"version"' package.json app.json
grep buildNumber app.json
echo "[DONE]"
