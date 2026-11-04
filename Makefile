# Shortcuts. `make help` lists them.
DEV := docker compose -f compose.dev.yml

.PHONY: help clone dev down logs test api-shell e2e up backup docs docs-build

help:            ## List targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

clone:           ## Clone omnipost-api and omnipost-ui next to this repo
	@test -d ../omnipost-api || git clone https://github.com/suryaanshrai/omnipost-api ../omnipost-api
	@test -d ../omnipost-ui || git clone https://github.com/suryaanshrai/omnipost-ui ../omnipost-ui

dev: clone       ## Run the whole stack for development (API :8000, UI :5173)
	$(DEV) up --build

down:            ## Stop the dev stack
	$(DEV) down

logs:            ## Follow dev stack logs
	$(DEV) logs -f

test:            ## API tests (against the dev stack's Postgres/Redis), then UI unit tests
	cd ../omnipost-api && DB_HOST=localhost DB_NAME=omni-db DB_USER=root DB_PASSWORD=root REDIS_HOST=localhost \
		DJANGO_SECRET_KEY=test OMNIPOST_KEK=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= poetry run pytest -q
	cd ../omnipost-ui && npm test

e2e:             ## Playwright smoke test against the running dev stack
	cd ../omnipost-ui && npm run e2e

api-shell:       ## Django shell in the dev stack
	$(DEV) exec api python manage.py shell

up:              ## Production stack (needs .env; see README)
	docker compose up -d --wait

backup:          ## Back up the production stack (see DEPLOY.md)
	./backup.sh

DOC_PAGES := DEPLOY.md APP_REVIEW.md ARCHITECTURE.md CONTRIBUTING.md CLA.md ROADMAP.md

docs-build:      ## Build the docs site into site/ (needs: pip install mkdocs)
	cp $(DOC_PAGES) docs/
	mkdocs build --strict

docs:            ## Preview the docs site at http://127.0.0.1:8001
	cp $(DOC_PAGES) docs/
	mkdocs serve -a 127.0.0.1:8001
