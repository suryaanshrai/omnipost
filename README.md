# omnipost

Orchestration for the OmniPost stack (API, worker, UI, Postgres, Redis).

## Quick start

```bash
mkdir omnipost && cd omnipost
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/suryaanshrai/omnipost/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/suryaanshrai/omnipost/main/.env.example
cp .env.example .env
```

Edit `.env` and set real values for `DJANGO_SECRET_KEY`, `OMNIPOST_KEK`, `DB_PASSWORD`, and
`REDIS_PASSWORD` (a blank/default value will refuse to start — that's
intentional, see below). Then:

```bash
docker compose up -d --wait
```

Or run `./setup.sh`, which does the same thing and prompts you to fill in
`.env` on first run.

> Requires Docker with Compose v2.

## Why `.env` is required

Earlier versions of this stack shipped a hardcoded Django `SECRET_KEY`,
`DEBUG=True`, and unauthenticated Postgres/Redis ports published to the host.
Those are gone. `docker-compose.yml` now fails fast (`:?` required-variable
syntax) if `DJANGO_SECRET_KEY`, `OMNIPOST_KEK`, `DB_PASSWORD`, or `REDIS_PASSWORD` aren't set,
rather than silently running insecurely.

## Services

| Service | Purpose |
|---|---|
| `ui` | React frontend (Vite) |
| `api` | Django REST API (gunicorn) |
| `worker` | RQ worker — runs scheduled publishes and background jobs |
| `reconciler` | Recovers any scheduled work lost by the queue (e.g. a Redis flush) |
| `token-refresher` | Proactively refreshes channel tokens nearing expiry |
| `metrics-poller` | Polls engagement metrics for recently published posts |
| `db` | Postgres (not published to the host) |
| `redis` | Redis, password-protected (not published to the host) |

## Observability

- `GET /metrics` on the `api` service is a Prometheus scrape target (publish
  success/failure per platform, RQ queue depth, Connection Health by
  platform, AI usage). Set `METRICS_AUTH_TOKEN` in `.env` to require a bearer
  token; blank leaves it open (no secrets in the output, same default as
  `/healthz`).
- Set `SENTRY_DSN` in `.env` to report exceptions to Sentry across every
  process role. Each image is tagged with its build's git SHA, which doubles
  as the Sentry release.

## Rolling back a deploy

Every image is pushed tagged `:latest` and `:<git-sha>`. To roll back, set
`IMAGE_TAG=<sha>` in `.env` (the SHA of the last known-good build) and
re-run `docker compose up -d`.

## Cloud deploy

See [DEPLOY.md](DEPLOY.md) for a recipe deploying this stack to a single
cloud VPS with TLS.

Source:
- API: https://github.com/suryaanshrai/omnipost-api
- UI: https://github.com/suryaanshrai/omnipost-ui
