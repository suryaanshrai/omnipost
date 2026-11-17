# Cloud deploy recipe

One VPS, Docker Compose, Caddy for TLS. Fits a 2 GB VPS (Hetzner,
DigitalOcean, Linode) for a solo creator or small team. 1 GB works if you
turn off the API docs and keep media small, but 2 GB leaves room for video
transcoding.

The stack: `ui`, `api`, `worker` (publishing), `worker-media` (media,
metrics, AI), `scheduler` (reconcile, recurrence, token refresh, metrics
polling), a one-shot `migrate`, plus `db` (Postgres) and `redis`.

## 1. Provision

Any VPS with a public IPv4 and two DNS `A` records pointing at it:

- `app.example.com` for the UI
- `api.example.com` for the API

```bash
curl -fsSL https://get.docker.com | sh
```

## 2. Get the stack

```bash
mkdir omnipost && cd omnipost
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/suryaanshrai/omnipost/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/suryaanshrai/omnipost/main/.env.example
curl -fsSL -o backup.sh https://raw.githubusercontent.com/suryaanshrai/omnipost/main/backup.sh && chmod +x backup.sh
cp .env.example .env
```

Edit `.env`:

| Variable | Value |
|---|---|
| `DJANGO_SECRET_KEY` | `openssl rand -base64 48` |
| `OMNIPOST_KEK` | `openssl rand -base64 32`. Encrypts every connected account. **Back it up**: lose it and every channel must be reconnected. |
| `DB_PASSWORD`, `REDIS_PASSWORD` | random strings (`openssl rand -hex 24`) |
| `DJANGO_ALLOWED_HOSTS` | `api.example.com` |
| `DJANGO_CORS_ALLOWED_ORIGINS`, `DJANGO_CSRF_TRUSTED_ORIGINS`, `FRONTEND_URL` | `https://app.example.com` |
| `PUBLIC_BASE_URL`, `VITE_API_URL` | `https://api.example.com` |
| `EMAIL_HOST` etc. | your SMTP provider, so password reset and verification emails are delivered |
| `METRICS_AUTH_TOKEN` | optional; `/metrics` is off until it's set |

## 3. Start the stack

```bash
docker compose up -d --wait
```

`--wait` returns once every service is healthy. A non-zero exit means
something is wrong: `docker compose ps` and `docker compose logs <service>`.

Ports 8000 (API) and 5173 (UI) are bound to `127.0.0.1`, so they're only
reachable through the proxy below. Docker's published ports bypass `ufw`,
which is why they aren't bound to `0.0.0.0`.

## 4. Put TLS in front of it

```bash
sudo apt-get install -y caddy
```

`/etc/caddy/Caddyfile`:

```
app.example.com {
    reverse_proxy localhost:5173
}

api.example.com {
    reverse_proxy localhost:8000
}
```

```bash
sudo systemctl reload caddy
```

Caddy gets and renews Let's Encrypt certificates on its own and sets
`X-Forwarded-Proto`, which the API needs to know requests arrived over HTTPS.

## 5. Verify

```bash
curl -sf https://api.example.com/healthz
curl -sf https://api.example.com/readyz
```

Both return `{"status": "ok", ...}`. Then open `https://app.example.com`
and create your account. For an admin login:
`docker compose exec api python manage.py createsuperuser`.

## Updating

```bash
docker compose pull
docker compose up -d --wait
```

`migrate` runs once before the API and workers start. Expect a few seconds
of downtime while containers are recreated.

## Rolling back

Every image is tagged with the git SHA it was built from. Set `IMAGE_TAG`
(API) and `UI_IMAGE_TAG` (UI) in `.env` to the last good SHAs, then:

```bash
docker compose up -d --wait
```

A rollback across a database migration needs that migration reversed
first; check the release notes before rolling back past one.

## Backups

State that a redeploy can't recreate: Postgres (`db-data`), uploaded media
(`media-data`, unless you use S3) and `OMNIPOST_KEK` in `.env`.

`backup.sh` writes a compressed database dump and a media archive to
`./backups`, and keeps the last 14 days:

```bash
./backup.sh
```

Run it nightly and copy `./backups` off the VPS (rclone, restic, or your
provider's snapshots):

```bash
crontab -e
# 17 3 * * * cd /root/omnipost && ./backup.sh >> backups/backup.log 2>&1
```

Restore:

```bash
docker compose stop api worker worker-media scheduler
gunzip -c backups/db-YYYY-MM-DD.sql.gz | docker compose exec -T db psql -U root -d omni-db
docker compose run --rm -v "$PWD/backups:/backups" --entrypoint sh api \
  -c 'tar -xzf /backups/media-YYYY-MM-DD.tar.gz -C /app/mediafiles'
docker compose up -d --wait
```

Test a restore on a spare VPS at least once; an untested backup is a guess.

## Media

Without an S3 bucket, the API serves uploads from `/media/` on
`PUBLIC_BASE_URL`, which is where Instagram, TikTok and the others fetch
them from. That needs `PUBLIC_BASE_URL` to be the public HTTPS address of
the API. With `AWS_STORAGE_BUCKET_NAME` set, media lives in S3/R2/B2 and
needs no backup here.
