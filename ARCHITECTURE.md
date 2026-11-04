# Architecture

One page on how OmniPost works. Code lives in three repos:
[omnipost-api](https://github.com/suryaanshrai/omnipost-api) (Django API and
job engine), [omnipost-ui](https://github.com/suryaanshrai/omnipost-ui)
(React app) and this one (compose stack, deploy docs).

## Processes

```
browser ── ui (nginx, static React build)
   │
   └──── api (gunicorn/Django) ── Postgres   ← source of truth
                │                    ▲
                └── Redis (RQ) ──────┤
                      │              │
              worker (publish)   worker-media (media, metrics, AI)
                                     │
              scheduler: reconcile · recurrence · token refresh · metrics polls
```

Postgres holds every post, target and attempt. Redis is only transport: if
it loses a job, the scheduler's reconcile task finds the due attempt in
Postgres and queues it again.

## Data model

```
Organization → Workspace → Membership (user, role)
                         → Channel (one connected account) → Credential (encrypted)
                         → Post → PostTarget (per channel) → PublishAttempt
                         → MediaAsset, VoiceProfile, QueueSlot, BlackoutWindow, RecurrenceRule
User → Notification
```

## Publishing a post

1. **Schedule.** `POST /posts/{id}/schedule/` sets each target to scheduled
   and creates attempt #1 for the target's current *epoch*, queued for
   `run_at`. Rescheduling, retrying or cancelling bumps the epoch, so any
   older queued attempt becomes a no-op.
2. **Claim.** A worker locks the attempt row, checks it's still wanted
   (right epoch, not cancelled), marks it RUNNING and commits.
3. **Call the platform**, outside any database transaction. Multi-step
   platforms (uploads, threads) return "not done yet" with their progress,
   which is saved so the next call resumes.
4. **Record.** Success marks the target published. A retryable error
   creates the next attempt with backoff, resuming from the saved step. A
   401 refreshes the token once and retries. Otherwise the target fails and
   owners, admins and the author get an alert (in-app, and by email).
5. **Crash safety.** A RUNNING attempt is never re-run. If its worker died,
   the reconciler marks it "unknown outcome" after 15 minutes, and the user
   decides whether to retry. Duplicate posts are worse than a missed one.

## Security

- Every query is scoped to the caller's workspaces, and every write checks
  their role there (viewer → owner). Related ids are validated against the
  same workspace.
- Channel credentials and AI keys are encrypted per value with AES-GCM
  under a key-encryption key (`OMNIPOST_KEK`).
- Requests to user-supplied addresses (AI source URLs, Mastodon instances,
  webhooks) go through `connectors/netguard.py`, which refuses private and
  metadata addresses.
- Sign-in, signup, password reset and AI calls are rate-limited; tokens
  expire after 30 days.
- The UI ships a strict Content-Security-Policy.

## Adding a platform

Write a connector in `omnipost-api/app/connectors/platforms/` that
subclasses `connectors.base.Connector`: declare `capabilities` (limits,
post kinds, media rules), implement `validate()` and `publish()`, and
optionally OAuth (`authorize_url`, `exchange_code`), `refresh()` (set
`refreshes_tokens = True`) and `fetch_metrics()`. Register it in
`connectors/registry.py`. Test it with `responses` (see the existing
connector tests). The UI picks it up from `GET /connectors/` with no
changes.
