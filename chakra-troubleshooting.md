# Troubleshooting

This section covers common issues encountered across the Chakra stack — Core, Backend, Frontend, and Docker — along with their root causes and solutions.

---

## Chakra Core

### `AttributeError: module 'ast' has no attribute 'Str'`

**Cause:** The project dependencies (Flask 2.0.2, Werkzeug 2.0.2) are incompatible with Python 3.12+, which removed `ast.Str` and `ast.Num`.

**Solution:** Use Python 3.9 via `pyenv`.

```bash
pyenv install 3.9.18
pyenv local 3.9.18
rm -rf chakra-core-env
python -m venv chakra-core-env
source chakra-core-env/bin/activate
pip install -r requirements.txt
```

Then always run Flask via:

```bash
python -m flask run
```

> Avoid plain `flask run` when multiple Python versions are present — it may pick the wrong interpreter.

---

### Chakra Core changes not reflecting after update

**Cause:** The Flask process is still running the old build, or the transpiler binary hasn't been rebuilt.

**Solution:** Re-pack the transpiler after Scala changes:

```bash
cd codebase/chakra-core
./pack.sh
```

Then restart the Flask process (typically running in a `tmux` session):

```bash
flask run --host=0.0.0.0 --port=5000
```

---

### `git reset --hard` wiped `components.json` or secrets

**Cause:** `git reset --hard FETCH_HEAD` discards all local changes, including config files like `components.json` that are not tracked in the repo.

**Solution:** Back up any local config files before pulling. Prefer the Jenkins job for Chakra Core deployments to avoid this issue.

---

## Backend (Django)

### Environment variables not loaded

**Cause:** `.env` was not sourced before running Django commands.

**Solution:** Always run the following before any `manage.py` command:

```bash
source chakra_backend/.env
```

---

### Backend can't connect to Chakra Core

**Cause:** `SERVER_URL` in the backend `.env` is misconfigured.

**Solution:** Ensure it points to the Flask server:

```bash
export SERVER_URL=http://127.0.0.1:5000/
```

---

### Elasticsearch warning on startup

**Symptom:**
```
Elasticsearch errored out
```

**Cause:** Elasticsearch is not running locally.

**Solution:** This warning does not affect core development functionality and can be safely ignored.

---

### Running management commands when backend is in Docker

**Solution:** Exec into the container, then source the env file:

```bash
docker compose exec chakra-backend bash
source chakra_backend/.env
python3 manage.py makemigrations
python3 manage.py migrate
python3 manage.py createsuperuser
```

For legacy Compose:

```bash
docker-compose exec chakra-backend bash
```

---

## Frontend (Next.js)

### `ECONNREFUSED ::1:60000`

**Cause:** Node.js is attempting to connect to the backend via IPv6 (`::1`) instead of IPv4.

**Solution:** Set the `PROXY` variable in `.env` to use `127.0.0.1` explicitly:

```env
PROXY=http://127.0.0.1:60000
```

> Do **not** use `localhost` — it resolves to `::1` on many modern systems.

Also start the backend bound to both IPv4 and IPv6:

```bash
python manage.py runserver "[::]:60000"
```

---

### Environment variable changes not taking effect

**Cause:** Next.js caches the previous build in `.next/`.

**Solution:** Clear the cache and restart:

```bash
rm -rf .next
./scripts/run-dev.sh -d 60000 -p 61000
```

---

### OAuth redirect error / login loop

**Cause:** Mismatch between frontend and backend OAuth configuration.

**Solution:** Ensure all four values are consistent:

| Location | Variable | Expected Value |
|----------|----------|----------------|
| Frontend `.env` | `NEXT_PUBLIC_OAUTH_REDIRECT_URI` | `http://localhost:61000/loading` |
| Frontend `.env` | `NEXT_PUBLIC_CLIENT_ID` | Your OAuth client ID |
| Backend `.env` | `OAUTH_REDIRECT_URI` | `http://localhost:61000/loading` |
| Backend `.env` | `CLIENT_ID` | Your OAuth client ID |

---

## Docker

### `./codebase` directory missing

**Cause:** Sub-repositories have not been cloned yet.

**Solution:**

```bash
./scripts/clone.sh
```

---

### Permission errors on bind mounts

**Cause:** Docker containers are running as a different user than the host.

**Solution:** Start Compose with the current user's UID:

```bash
CURRENT_UID="$(id -u):$(id -g)" docker-compose up -d
# or (Compose v2)
CURRENT_UID="$(id -u):$(id -g)" docker compose up -d
```

Alternatively, use the provided convenience script which handles this automatically:

```bash
./scripts/prod.sh
```

---

### Port already in use

**Cause:** Because all services use `network_mode: host`, they bind directly to host ports. A conflicting local service may already be using the same port.

**Solution:** Stop the conflicting service, or adjust the port in the upstream app configuration. Common default ports to check:

| Service | Port |
|---------|------|
| Postgres | 5432 |
| Backend (Gunicorn) | 8000 |
| Backend (Daphne) | 8001 |
| Frontend | 3000 |
| RabbitMQ | 5672 |
| Memcached | 11211 |
| Chakra Core | 5000 |

---

### `sed -i` errors when running build scripts on macOS

**Cause:** Build scripts use GNU `sed` syntax, which is incompatible with the BSD `sed` on macOS.

**Solution:** Install GNU sed via Homebrew and use `gsed`, or run build scripts on Linux.

```bash
brew install gnu-sed
```

---

## "Everything went wrong" Recovery

If multiple services are down or in a broken state, restart the full stack from the `chakra-docker` root:

```bash
docker-compose up -d
# or (Compose v2)
docker compose up -d
```