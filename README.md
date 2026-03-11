# Chakra (Docker Stack)

Chakra is a **Component Content Management System (CCMS)** built for **IIT Roorkee**. It enables editors to build pages using UI-kit components, generates XML representations, and renders/serves websites using a transpiler + backend services.

This repository (`chakra-docker`) is the **Docker + orchestration layer** for running the Chakra stack locally (and as a base for deployment): Postgres, RabbitMQ, Memcached, Django backend (Gunicorn + Daphne + Celery), Next.js frontend, and Nginx config templates.

## What’s in the stack

- **`chakra-backend`** (Django): APIs, auth/permissions, file manager, XML/HTML workflows. Runs **Gunicorn** (HTTP) + **Daphne** (ASGI) + **Celery** (worker) under `supervisord`.
- **`chakra-frontend`** (Next.js): Editor/UI to build pages and generate XML.
- **`chakra-core`** (Scala + Python/Flask): Transpiler and supporting services for turning XML into static HTML (and some dynamic component support).
- **Postgres**: Primary database.
- **RabbitMQ**: Message broker (Celery).
- **Memcached**: Caching.
- **Nginx templates**: Reverse proxy config templates under `nginx/` (not started by `docker-compose.yml` in this repo).

Upstream repos are cloned into this repo’s `./codebase/` directory by scripts in this repo.

## Repo layout

- **`docker-compose.yml`**: Brings up database, backend, frontend, memcached, rabbitmq (host-networked).
- **`scripts/clone.sh`**: Clones `chakra-core`, `chakra-backend`, `chakra-frontend`, `chakra-library` into `./codebase/`.
- **`scripts/build/*`**: Builds Docker images and generates env files from stencils.
- **`postgres/`**, **`rabbitmq/`**, **`memcached/`**, **`django/`**, **`next/`**: Docker build contexts.
- **`nginx/`**: Nginx config templates (TLS server block + upstreams + includes).
- **`chakrabackup-script/`**: Backup scripts (see `chakrabackup-script/README.md`).

## Prerequisites

- **Docker** + **Docker Compose**
- **git**
- **Node.js + yarn** (used by `scripts/build/next.sh` to install deps before building the image)
- **Python3 (3.9 Required)** (for running `chakra-core` Flask server locally in `scripts/prod.sh` / `scripts/development.sh`)

If you work on the transpiler itself:

- **Scala + sbt** (see `chakra-core/README.md` once cloned)

## Quick start (recommended: Docker for infra + backend/frontend, local `chakra-core`)

### 1) Clone the codebase into `./codebase/`

From the root of this repo:

```bash
./scripts/clone.sh
```

This creates:

```text
codebase/
  chakra-backend/
  chakra-frontend/
  chakra-core/
  chakra-library/
```

### 2) Create required env files

This repo uses “stencil” env files that you copy/fill once.

#### Postgres

Generate `postgres/database.env` from `postgres/database_stencil.env`:

```bash
bash ./scripts/build/postgres.sh
```

#### RabbitMQ

Generate `rabbitmq/message_broker.env` from `rabbitmq/message_broker_stencil.env`:

```bash
bash ./scripts/build/rabbitmq.sh
```

#### Chakra backend (Django)

Inside the cloned backend repo, create:

- `codebase/chakra-backend/chakra_backend/.env`

Start from the backend stencil:

```bash
cp codebase/chakra-backend/chakra_backend/stencil.env codebase/chakra-backend/chakra_backend/.env
```

Then edit values in `.env` (database creds, oauth creds, core server URL, allowed hosts, cache + rabbitmq creds, etc.). The stencil lives here:

- `codebase/chakra-backend/chakra_backend/stencil.env`

#### Chakra core (Flask)

Create:

- `codebase/chakra-core/.env`

From:

```bash
cp codebase/chakra-core/stencil.env codebase/chakra-core/.env
```

`chakra-core/.env` needs:

- `SECRET_FLASK`
- `CODEBASE_PATH` (path to the `codebase/` directory)

Install Chakra core Python dependencies (used by `flask run`):

```bash
cd codebase/chakra-core
python3 -m venv chakra-core-env
source chakra-core-env/bin/activate
pip install -r requirements.txt
cd ../../
```

### 3) Build Docker images

From repo root:

```bash
bash ./scripts/build/postgres.sh
bash ./scripts/build/rabbitmq.sh
bash ./scripts/build/memcached.sh
bash ./scripts/build/django.sh
bash ./scripts/build/next.sh
```

### 4) Start the stack

This repo provides a convenience script that:

- starts all Docker services via Compose
- then runs `chakra-core` (Flask) locally

```bash
./scripts/prod.sh
```

For core-only development (starts just Postgres + `chakra-core`):

```bash
./scripts/development.sh
```

If you prefer manual Compose:

```bash
CURRENT_UID="$(id -u):$(id -g)" docker-compose up -d
# or (Compose v2)
CURRENT_UID="$(id -u):$(id -g)" docker compose up -d
```

## Ports (host networking)

All services in `docker-compose.yml` use `network_mode: host`, so they bind directly on your host.

Common ports:

- **Postgres**: `5432`
- **Backend (Gunicorn)**: `8000`
- **Backend (Daphne / ASGI)**: `8001`
- **Frontend (Next.js)**: `3000`
- **RabbitMQ (AMQP)**: `5672` (and **Management UI** is typically `15672`)
- **Memcached**: `11211`
- **Chakra core (Flask)**: `5000` (default Flask port)

## Common developer workflows

### Django management commands (migrations, superuser, etc.)

Because the backend runs in Docker, run management commands inside the container:

```bash
docker compose exec chakra-backend bash
source chakra_backend/.env
python3 manage.py makemigrations
python3 manage.py migrate
python3 manage.py createsuperuser
```

If you use legacy Compose:

```bash
docker-compose exec chakra-backend bash
```

Important: **source** the backend `.env` before running `manage.py`.

### Frontend dev server (optional)

The production-ish container runs `yarn build` + `yarn start`. For local development, the frontend repo also ships a helper that runs Next.js dev mode inside Docker on a high port:

```bash
cd codebase/chakra-frontend
./scripts/run-dev.sh -d 60000 -p 61000
```

### Chakra core transpiler changes

If you change Scala transpiler code in `codebase/chakra-core`, you’ll commonly need to re-pack:

```bash
cd codebase/chakra-core
./pack.sh
```

## “Rough” non-Docker local setup (legacy notes)

If you’re running everything on your host (instead of Docker), the rough sequence is:

- **Backend**
  - Create `chakra-backend/chakra_backend/.env`
  - `pip install -r requirements.txt`
  - Setup Postgres user/db (example: user `naruto`, db `chakradb`)
  - Run `python3 manage.py makemigrations && python3 manage.py migrate`
  - Create admin user: `python3 manage.py createsuperuser`
  - Run generator scripts (example mentioned: `node_gen_util.py`)
  - Run: `python3 manage.py runserver 60000`
- **Celery**
  - `celery -A chakra_backend worker --loglevel=INFO`
- **Frontend**
  - `./scripts/run-dev.sh -d 60000 -p 61000`
- **Chakra core**
  - Create venv, install requirements, set `.env`, run `flask run`
- **Services**
  - Start Memcached + RabbitMQ + Postgres

Note: changing `pg_hba.conf` auth to `trust` is convenient for local dev but **unsafe** on shared machines. Prefer proper local passwords / `md5/scram` auth where possible.

## Production deployment (server)

In production, updates are usually applied via **Jenkins jobs**. If Jenkins is unavailable, use the manual commands below as a fallback.

### Important notes

- **Avoid putting credentials in shell history**: prefer Jenkins credentials bindings, deploy keys, or a GitHub token injected as an env var in CI.
- **Be careful with `git reset --hard`**: it will wipe any server-local changes (for Chakra core this often includes secrets/config like `components.json`).

### Backend (Django container)

- **Preferred**: run the existing Jenkins job for `chakra-backend`.
- **Manual fallback** (from the `chakra-docker` repo root on the server):

```bash
cd /path/to/chakra-docker/codebase/chakra-backend &&
git pull "https://${USER}:${PW}@github.com/IMGIITRoorkee/chakra-backend.git" master --rebase &&
docker restart chakra-docker_chakra-backend_1
```

### Chakra core (transpiler build + Flask)

- **Preferred**: run the existing Jenkins job for `chakra-core`.
- **Manual fallback** (use with caution; see note about `components.json` above):

```bash
cd /path/to/chakra-docker/codebase/chakra-core &&
source chakra-core-env/bin/activate &&
git fetch "https://${USER}:${PW}@github.com/IMGIITRoorkee/chakra-core.git" &&
git reset --hard FETCH_HEAD &&
./pack.sh
```

If Chakra core changes don’t reflect (or Flask is stuck), restart the Flask process (often running in a `tmux` session). If needed, stop it with `Ctrl+C` and start it again so it binds on port `5000`:

```bash
flask run --host=0.0.0.0 --port=5000
```

### Frontend (Next.js container)

- **Preferred**: run the existing Jenkins job for `chakra-frontend`.
- **Manual fallback**:

```bash
cd /path/to/chakra-docker/codebase/chakra-frontend &&
git pull "https://${USER}:${PW}@github.com/IMGIITRoorkee/chakra-frontend.git" master --rebase &&
docker restart chakra-docker_chakra_frontend_1
```

### Chakra library

- **Preferred**: run the existing Jenkins job for `chakra-library`.
- **Manual fallback** (repo location may differ per server):

```bash
cd /path/to/chakra-library &&
sudo git pull origin staging --rebase
```

### “Everything went wrong” recovery

From the `chakra-docker` repo root on the server:

```bash
docker-compose up -d
# or (Compose v2)
docker compose up -d
```

## Troubleshooting

- **`./codebase` missing**: run `./scripts/clone.sh`.
- **Permissions issues on bind mounts**: bring up compose via `./scripts/prod.sh` or set `CURRENT_UID="$(id -u):$(id -g)"` when running `docker-compose`.
- **Backend can’t talk to core**: confirm `SERVER_URL` in backend `.env` points to your Flask server (typically `http://127.0.0.1:5000`).
- **Ports already in use**: because containers use host networking, stop conflicting services or change ports in the upstream app configs.
- **macOS `sed -i` errors when running build scripts**: some scripts expect GNU `sed`. Install `gnu-sed` (Homebrew) and use `gsed`, or run the build steps on Linux.

- For more errors [refer this](chakra-troubleshooting.md)