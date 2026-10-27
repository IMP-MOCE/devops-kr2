#!/usr/bin/env bash
# Run on the VM; do not print or copy the secret.
set -euo pipefail
cd "${KR2_DIR:-/home/devops/kr2}"
password=$(sed -n 's/^REDIS_PASSWORD=//p' .env)
trap 'unset password' EXIT
[[ "$password" =~ ^[0-9a-f]{32,}$ ]]
set +e
grep -rlF --exclude=.env -- "$password" .
rc=$?
set -e
case "$rc" in
    0) echo 'FAIL: current secret found outside .env'; exit 1 ;;
    1) echo 'PASS: current secret absent from delivered project files' ;;
    *) echo 'FAIL: secret search error'; exit 1 ;;
esac
docker run --rm --user root kr2-app:1.0 find / -xdev -name .env
stat -c '%a %U %n' .env
