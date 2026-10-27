#!/usr/bin/env bash
# Isolated educational test; restores loopback publication even on failure.
set -euo pipefail
cd "${KR2_DIR:-/home/devops/kr2}"
backup=$(mktemp)
cp docker-compose.yml "$backup"
restore() {
    cp "$backup" docker-compose.yml
    rm -f "$backup"
    docker compose up -d >/dev/null
}
trap restore EXIT
sed -i 's/127.0.0.1:8002:8002/8002:8002/' docker-compose.yml
docker compose up -d
set +e
bash scripts/audit.sh > /tmp/kr2-audit-negative.log 2>&1
rc=$?
set -e
printf 'Negative audit exit: %s\n' "$rc" >> /tmp/kr2-audit-negative.log
[[ "$rc" == 1 ]]
restore
trap - EXIT
bash scripts/audit.sh | tee /tmp/kr2-audit-restored.log
echo 'Restored audit exit: 0'
