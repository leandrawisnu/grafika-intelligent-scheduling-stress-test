#!/usr/bin/env bash
# Seed a load-test account (k6) into the pengguna table.
# Standalone: pure SQL, no Go module needed.
# Idempotent: safe to re-run (upsert by email).
#
# Usage:
#   ./scripts/seed-loadtest-user.sh                      # default account
#   ./scripts/seed-loadtest-user.sh <email>              # custom email
#   ./scripts/seed-loadtest-user.sh <email> <hash>       # custom email + argon2id hash
#
# Default: loadtest@grafika.sch.id / GrafikaLoadTest2026!
# (hash pre-computed with the backend's argon2id params — see
#  grafika-intelligent-scheduling-backend/scripts/hash-sandi)
#
# The script prints the credentials — copy them into .env (K6_USER / K6_PASSWORD).

set -euo pipefail

EMAIL="${1:-loadtest@grafika.sch.id}"
HASH="${2:-\$argon2id\$v=19\$m=65536,t=1,p=4\$w7YAPjiVucWiY5i1IX0/qQ\$UvmFDTtKNPIOMpPdc7+L2XRFvQhxrWV2hNOZjijPBt8}"

if [[ -n "${DATABASE_URL:-}" ]]; then
  PSQL_URL="$DATABASE_URL"
else
  echo "Set DATABASE_URL (postgres://user:pass@host:5432/dbname) or DB_* env vars." >&2
  exit 1
fi

command -v psql >/dev/null 2>&1 || {
  echo "psql not found. Install the PostgreSQL client." >&2
  exit 1
}

echo "[seed-loadtest] upserting user $EMAIL (role=admin)"
psql "$PSQL_URL" -v ON_ERROR_STOP=1 \
  -v email="$EMAIL" \
  -v hash="$HASH" \
  <<'SQL'
INSERT INTO pengguna (email, password_hash, peran, jurusan_id, aktif)
VALUES (:'email', :'hash', 'admin', NULL, true)
ON CONFLICT (email) DO UPDATE SET
  password_hash = EXCLUDED.password_hash,
  aktif = true,
  updated_at = now();
SQL

echo "[seed-loadtest] done. Credentials for .env:"
echo "  K6_USER=$EMAIL"
if [[ $# -lt 2 ]]; then
  echo "  K6_PASSWORD=GrafikaLoadTest2026!"
fi
