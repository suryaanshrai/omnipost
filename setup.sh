#!/bin/bash
# Fetches the compose file and .env template, then brings the stack up.
# Migrations now run automatically inside the api container's entrypoint
# (docker/entrypoint.sh in omnipost-api), so this script no longer races
# Postgres readiness with a manual `docker compose exec ... migrate`.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/suryaanshrai/omnipost/main"

curl -fsSL -o docker-compose.yml "$REPO_RAW/docker-compose.yml"

if [ ! -f .env ]; then
  curl -fsSL -o .env.example "$REPO_RAW/.env.example"
  curl -fsSL -o backup.sh "$REPO_RAW/backup.sh" && chmod +x backup.sh
  cp .env.example .env
  echo "Created .env from .env.example — edit it with real secrets before continuing."
  echo "At minimum set DJANGO_SECRET_KEY, OMNIPOST_KEK, DB_PASSWORD, and REDIS_PASSWORD, then re-run this script."
  exit 1
fi

docker compose up -d --wait
echo "OmniPost is up. UI: http://localhost:5173  API: http://localhost:8000"
echo "For a public deploy with TLS and backups, see DEPLOY.md."
