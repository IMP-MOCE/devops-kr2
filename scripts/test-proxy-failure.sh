#!/usr/bin/env bash
# Rehearsal for oral defense; changes only this project's app container.
set -euo pipefail
cd "${KR2_DIR:-/home/devops/kr2}"
restore() { docker compose up -d app >/dev/null; }
trap restore EXIT
docker compose stop app
curl --resolve notes.devops.local:443:127.0.0.1 \
    --cacert /etc/ssl/certs/kr2.crt -s -o /dev/null -w 'HTTPS status with app stopped: %{http_code}\n' \
    https://notes.devops.local/health
tail -n 2 /var/log/nginx/kr2.error.log
restore
trap - EXIT
for attempt in {1..20}; do
    if curl --resolve notes.devops.local:443:127.0.0.1 \
        --cacert /etc/ssl/certs/kr2.crt -fsS https://notes.devops.local/health; then
        echo 'HTTPS restored'
        exit 0
    fi
    sleep 1
done
exit 1
