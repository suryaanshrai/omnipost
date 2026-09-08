# Cloud deploy recipe

A minimal, single-VPS deployment of the full stack (`ui`, `api`, `worker`,
`reconciler`, `recurrence`, `token-refresher`, `metrics-poller`, `db`,
`redis`) behind TLS, using the same `docker-compose.yml` as local dev. No
Kubernetes, no managed database required — this fits a $6-12/mo VPS
(Hetzner, DigitalOcean, Linode) comfortably for a solo/small-team workspace.

## 1. Provision

Any VPS with Docker + Compose v2 and a public IPv4. A domain (or subdomain)
pointed at it via an `A` record.

```bash
curl -fsSL https://get.docker.com | sh
```

## 2. Get the stack

```bash
mkdir omnipost && cd omnipost
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/suryaanshrai/omnipost/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/suryaanshrai/omnipost/main/.env.example
cp .env.example .env
```

Edit `.env`:
- `DJANGO_SECRET_KEY` — `openssl rand -base64 48`
- `OMNIPOST_KEK` — `openssl rand -base64 32` (wraps every stored credential —
  losing this makes every connected channel unrecoverable, back it up)
- `DB_PASSWORD`, `REDIS_PASSWORD` — random strings
- `DJANGO_ALLOWED_HOSTS` — your domain, e.g. `app.example.com`
- `DJANGO_CORS_ALLOWED_ORIGINS` / `PUBLIC_BASE_URL` / `VITE_API_URL` — your
  domain with scheme, e.g. `https://app.example.com`
- `SENTRY_DSN`, `METRICS_AUTH_TOKEN` — optional, see README.md#observability

## 3. Put TLS in front of it

`docker-compose.yml` doesn't publish 443 itself — put a reverse proxy in
front. Caddy is the least ceremony (automatic Let's Encrypt, no separate
certbot/renewal process to manage):

```bash
sudo apt-get install -y caddy   # or: docker run instead, if you'd rather not install on the host
```

`/etc/caddy/Caddyfile`:

```
app.example.com {
    reverse_proxy localhost:8000
}
```

The `ui` container serves the SPA and proxies `/api/` calls to `api` per its
own nginx config — point Caddy at whichever port your `ui`/`api` split
expects (check `omnipost-ui/docker/`); if you're serving API and UI on
separate subdomains instead, add a second Caddyfile block pointed at the
`ui` container's port.

```bash
sudo systemctl reload caddy
```

## 4. Start the stack

```bash
docker compose up -d --wait
```

`--wait` blocks until every service reports healthy (`api`'s healthcheck
only passes once `migrate` has completed — see docker-compose.yml) — a
non-zero exit here means something's actually wrong, not just slow.

## 5. Verify

```bash
curl -sf https://app.example.com/api/healthz
curl -sf https://app.example.com/api/readyz
```

Both should return `{"status": "ok", ...}`. Create your first user via
`docker compose exec api python manage.py createsuperuser`, or through the
UI's signup flow.

## Updating

```bash
docker compose pull
docker compose up -d --wait
```

Pulls `:latest` (or whatever `IMAGE_TAG` is pinned to in `.env`) and
recreates any container whose image changed. Migrations run automatically
as part of the `api` container's entrypoint before it starts serving.

## Rolling back

Every image is also tagged with the git SHA it was built from. Set
`IMAGE_TAG=<sha>` in `.env` to the last known-good build, then:

```bash
docker compose up -d --wait
```

## Backups

The only state that isn't reproducible from a redeploy is `db-data` (Postgres)
and, if you're not using S3-compatible storage, `media-data`:

```bash
docker compose exec db pg_dump -U root omni-db | gzip > "backup-$(date +%F).sql.gz"
```

Run that on a cron; store the output somewhere off the VPS. If
`AWS_STORAGE_BUCKET_NAME` is set, media already lives in S3/R2/B2 and needs
no separate backup here.
