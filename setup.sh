#!/bin/bash

curl -s -o docker-compose.yml https://raw.githubusercontent.com/suryaanshrai/omnipost/main/docker-compose.yml

docker compose up api -d

docker compose exec api python manage.py migrate

docker compose down && docker compose up