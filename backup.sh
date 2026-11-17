#!/bin/sh
# Nightly backup: Postgres dump + uploaded media, kept for $KEEP_DAYS days.
# Run from the directory holding docker-compose.yml. Copy ./backups off the
# server afterwards; a backup on the same disk doesn't survive losing it.
set -eu

KEEP_DAYS="${KEEP_DAYS:-14}"
OUT="${BACKUP_DIR:-./backups}"
STAMP="$(date +%F)"
mkdir -p "$OUT"

docker compose exec -T db pg_dump -U root -d omni-db | gzip > "$OUT/db-$STAMP.sql.gz.part"
mv "$OUT/db-$STAMP.sql.gz.part" "$OUT/db-$STAMP.sql.gz"

docker compose run --rm -T -v "$(cd "$OUT" && pwd):/backups" --entrypoint sh api \
  -c "tar -czf /backups/media-$STAMP.tar.gz -C /app/mediafiles ."

find "$OUT" -name 'db-*.sql.gz' -mtime +"$KEEP_DAYS" -delete
find "$OUT" -name 'media-*.tar.gz' -mtime +"$KEEP_DAYS" -delete

echo "Backed up to $OUT (db-$STAMP.sql.gz, media-$STAMP.tar.gz)."
echo "Reminder: OMNIPOST_KEK in .env is needed to read connected accounts; keep a copy somewhere safe."
