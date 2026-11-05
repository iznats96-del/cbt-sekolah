#!/usr/bin/env bash
# Backup Supabase DB via Management API SQL export
# Usage: ./backup_supabase.sh
# Output: D:/cbt-sekolah/backups/supabase_YYYYMMDD_HHMMSS.sql

set -euo pipefail

TOKEN="sbp_fce55249edfaabc241f23ea86e4fd406f5db52f6"
REF="yukqngrtgevveimhrwke"
BACKUP_DIR="D:/cbt-sekolah/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTFILE="${BACKUP_DIR}/supabase_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

# Dump all public tables via pg_dump through Management API
# Note: Management API /database/query only runs SELECT; for full dump we use direct pg_dump
# Since we don't have DB password in env, we use the service role key via Supabase REST to export data table-by-table
# Alternative: use supabase CLI if installed, or psql with connection string from dashboard

# For now: export schema + data via pg_dump using direct connection
# Connection string format: postgresql://postgres.[ref]:[password]@db.[ref].supabase.co:5432/postgres
# Password must be set in SUPABASE_DB_PASSWORD env var

if [ -z "${SUPABASE_DB_PASSWORD:-}" ]; then
  echo "ERROR: SUPABASE_DB_PASSWORD not set. Get it from Supabase Dashboard > Settings > Database > Connection string > Transaction mode > Password"
  exit 1
fi

PGPASSWORD="$SUPABASE_DB_PASSWORD" pg_dump \
  --host="db.${REF}.supabase.co" \
  --port=5432 \
  --username="postgres.${REF}" \
  --dbname="postgres" \
  --schema=public \
  --no-owner \
  --no-privileges \
  --clean \
  --if-exists \
  -f "$OUTFILE"

echo "Backup saved: $OUTFILE ($(du -h "$OUTFILE" | cut -f1))"

# Keep only last 7 backups
ls -t "${BACKUP_DIR}"/supabase_*.sql 2>/dev/null | tail -n +8 | xargs -r rm -f
echo "Old backups pruned (keeping last 7)"