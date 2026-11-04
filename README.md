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
| `ui` | React frontend (static build served by nginx) |
| `api` | Django REST API (gunicorn) |
| `migrate` | Runs database migrations once, then exits; everything API-side waits for it |
| `worker` | Publishes posts (RQ: `publish`, `maintenance`, `default` queues) |
| `worker-media` | Media probing/transcoding, metrics polls, AI jobs, kept apart so they never delay a publish |
| `scheduler` | Periodic tasks in one process: recovers lost or stuck publishes, fires recurring posts, refreshes expiring channel tokens, queues metrics polls |
| `db` | Postgres (not published to the host) |
| `redis` | Redis with append-only persistence and a password (not published to the host) |

The API and UI ports are bound to `127.0.0.1`; put the TLS proxy from
[DEPLOY.md](DEPLOY.md) in front. For a quick local try without TLS, set
`DJANGO_SECURE_SSL_REDIRECT=false` in `.env`.

## Observability

- `GET /metrics` on the `api` service is a Prometheus scrape target (publish
  success/failure per platform, RQ queue depth, channel health, AI usage).
  It's off in production until `METRICS_AUTH_TOKEN` is set; scrape it with
  `Authorization: Bearer <token>`.
- Set `SENTRY_DSN` to report exceptions to Sentry from every process. Each
  image is tagged with its build's git SHA, which doubles as the Sentry
  release.

## Backups

`./backup.sh` dumps Postgres and archives uploaded media into `./backups`,
keeping 14 days. Run it nightly and copy the folder off the server. Keep a
copy of `OMNIPOST_KEK` too: without it, stored channel credentials can't be
decrypted. Restore steps are in [DEPLOY.md](DEPLOY.md#backups).

## Rolling back a deploy

Every image is pushed tagged `:latest` and `:<git-sha>`. To roll back, set
`IMAGE_TAG=<sha>` (API) and `UI_IMAGE_TAG=<sha>` (UI) in `.env` to the last
known-good builds and re-run `docker compose up -d --wait`.

## Development

`make dev` clones the API and UI next to this repo and runs everything
with hot reload (see `compose.dev.yml`). `make help` lists the other
shortcuts. How the pieces fit: [ARCHITECTURE.md](ARCHITECTURE.md).
Contributing: [CONTRIBUTING.md](CONTRIBUTING.md).

## Cloud deploy

See [DEPLOY.md](DEPLOY.md) for a recipe deploying this stack to a single
cloud VPS with TLS.

Source:
- API: https://github.com/suryaanshrai/omnipost-api
- UI: https://github.com/suryaanshrai/omnipost-ui
