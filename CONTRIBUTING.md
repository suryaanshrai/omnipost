# Contributing

Thanks for helping. A few things make reviews quick.

## Setup

```bash
git clone https://github.com/suryaanshrai/omnipost && cd omnipost
make dev        # clones omnipost-api and omnipost-ui next to it, runs everything
```

The UI is at http://localhost:5173 and the API at http://localhost:8000.
Emails print to the `api` container's log.

## Before opening a pull request

- **API** (`omnipost-api`): `poetry run pytest`, `poetry run ruff check .`,
  `poetry run mypy app`. If you changed an endpoint, regenerate the schema:
  `cd app && python manage.py spectacular --file ../schema.yml`.
- **UI** (`omnipost-ui`): `npm run lint`, `npm run typecheck`, `npm test`,
  and `npm run gen:api` after an API schema change. For anything touching
  sign-up, compose or publishing, run `npm run e2e` against the dev stack.
- A bug fix comes with a test that fails without it.
- Keep a pull request to one change; say why in the description.

CI runs the same checks on every pull request.

## Where things are

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces fit, and each
repo's README for its layout.

## Licensing

OmniPost is GPL-3.0. By contributing you agree your contribution is
licensed under the same terms.
