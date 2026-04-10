# Chakra Production Architecture

> Verified against production servers (root1/bifrost + root2/edith) on 2026-04-10.

## Two-Server Overview

Chakra runs across two physical servers connected by `lsyncd` (continuous rsync over SSH).

```
┌─────────────────────────────────────────────────────────────────────────┐
│  root1 / bifrost (192.168.121.230)                                      │
│  Application Server — runs all logic, stores all source data            │
│                                                                         │
│  ┌──────────── Docker (host networking) ──────────────────────┐         │
│  │  chakra-backend    Django (Gunicorn:8000 + Daphne:8001     │         │
│  │                    + Celery worker) under supervisord       │         │
│  │  chakra-frontend   Next.js (PM2, port 3000)                │         │
│  │  database          PostgreSQL (port 5432)                   │         │
│  │  cache             Memcached (port 11211)                   │         │
│  │  message-broker    RabbitMQ (port 5672)                     │         │
│  └────────────────────────────────────────────────────────────┘         │
│                                                                         │
│  ┌──────────── Host Processes ────────────────────────────────┐         │
│  │  chakra-core       Flask:5000 + Scala transpiler binary     │         │
│  │                    (runs in a tmux session named "prod")    │         │
│  │  lsyncd            Continuous rsync → root2                 │         │
│  │  Nginx             chakra.channeli.in (port 443)            │         │
│  │  libretranslate    Hindi translation (Docker, port 13338)   │         │
│  └────────────────────────────────────────────────────────────┘         │
│                                                                         │
│  Filesystem:                                                            │
│  /home/root1/chakra-docker/                                             │
│    codebase/                                                            │
│      chakra-backend/                                                    │
│        website/                                                         │
│          XML/          ← Source content (20 GB, 15,280 asset files)     │
│          HTML/         ← Published output (synced to root2)             │
│          JoshUsers/    ← Josh user sites (synced to root2)              │
│        media_files/                                                     │
│          preview/      ← Temporary preview images (cleaned hourly)      │
│        reverse_proxy_configurations/                                    │
│          subdomains/   ← Generated nginx configs (synced to root2)      │
│          shorturls/    ← Short URL configs (synced to root2)            │
│          josh-subdomains/                                               │
│      chakra-core/                                                       │
│        components.json ← Transpiler config (assets_host lives here)     │
│      chakra-frontend/                                                   │
│      chakra-library/                                                    │
│                                                                         │
│  S3 mounts: /home/root1/s3bucket, /home/root1/s3bucket2                 │
│                                                                         │
│  Cron jobs:                                                             │
│    Weekly: database_backup.sh                                           │
│    Daily:  incremental_backup_to_aws_script.sh                          │
│    Hourly: tmp_clear.sh (via Django celery cron, cleans preview/)       │
└─────────────────────────────────────────────────────────────────────────┘
            │
            │  lsyncd (4 sync streams, rsync over SSH)
            │  Key: /home/root1/.ssh/website-key
            ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  root2 / edith (192.168.121.188)                                        │
│  Static File Server — serves published websites to the public           │
│                                                                         │
│  ┌──────────── Host Processes ────────────────────────────────┐         │
│  │  Nginx (port 443)  18+ subdomain server blocks              │         │
│  │  inotifywait       Watches /etc/nginx/ → auto-reloads nginx │         │
│  └────────────────────────────────────────────────────────────┘         │
│                                                                         │
│  Filesystem:                                                            │
│  /home/root2/                                                           │
│    new_website/        ← 70 GB, synced from root1 website/HTML/         │
│      Departments/                                                       │
│      Centres/                                                           │
│      Schools/                                                           │
│      Josh Users/       ← Synced from root1 website/JoshUsers/           │
│      ...                                                                │
│    s3bucket/           ← S3 mount (backups, faculty websites)           │
│      public/Websites/  ← Faculty personal websites                      │
│                                                                         │
│  Nginx configs (synced from root1):                                     │
│  /etc/nginx/                                                            │
│    sites-enabled/      ← Per-subdomain configs (cec.conf, ece.conf...)  │
│    sites-available/                                                     │
│      subdomains/       ← Synced from reverse_proxy_configurations/      │
│      josh-subdomains/                                                   │
│    conf.d/includes/    ← Faculty routes + short URLs                    │
│                                                                         │
│  No Docker, no app logic, no cron, no database.                         │
│  Pure static file serving.                                              │
└─────────────────────────────────────────────────────────────────────────┘
```

## lsyncd Sync Streams (root1 → root2)

Configured at `/etc/lsyncd/lsyncd.conf.lua` on root1. All syncs use the same SSH key.

| # | Source (root1) | Target (root2) | Purpose |
|---|---|---|---|
| 1 | `website/HTML/` | `/home/root2/new_website/` | Published HTML pages + their `assets/` folders |
| 2 | `website/JoshUsers/` | `/home/root2/new_website/Josh Users/` | Josh user websites |
| 3 | `reverse_proxy_configurations/subdomains/` | `/etc/nginx/sites-available/subdomains/` | Nginx subdomain configs |
| 4 | `reverse_proxy_configurations/shorturls/` | `/etc/nginx/conf.d/includes/` | Short URL location blocks |
| 5 | `reverse_proxy_configurations/josh-subdomains/` | `/etc/nginx/sites-available/josh-subdomains/` | Josh subdomain configs |

When lsyncd pushes new nginx configs, `inotifywait` on root2 detects the change and triggers `hot-nginx-reload.sh`.

## Nginx Routing

### root1 — chakra.channeli.in (application traffic)

The nginx config on root1 (template: `nginx/conf.d/chakra_stencil.conf`) routes:

| Path Pattern | Destination | Purpose |
|---|---|---|
| `/chakra_auth/*`, `/generator/*`, `/filemanager/*` | Gunicorn (127.0.0.1:8000) | Django API |
| `/ws/*` | Daphne (127.0.0.1:8001) | WebSocket |
| `/media/*` | `/media_files/` (filesystem alias) | Media files (preview images, uploads) |
| `/static/*` | `/static_files/` | Frontend static assets |
| `/static_backend/*` | Backend collectstatic | Django admin static |
| `/_next/static/*` | Next.js build output | Frontend JS/CSS |
| `/*` (fallback) | Next.js (127.0.0.1:3000) | Frontend app |

### root2 — subdomain.iitr.ac.in (public websites)

Each subdomain gets its own nginx server block. Example (`cec.iitr.ac.in`):

```nginx
server {
    listen 443 ssl;
    server_name .cec.iitr.ac.in;
    root '/home/root2/new_website/cec';
    ssl_certificate /certificates/iitr-certificate/ssl.cert;
    # ... standard SSL config ...
    include conf.d/includes/compression.conf;
}
```

Faculty profile pages use `alias` directives pointing to specific HTML files:
```nginx
location "/~ECE/Faculty_Name" {
    default_type "text/html";
    alias '/home/root2/new_website/Departments/.../Faculty/100XXX.html';
}
```

Faculty personal websites are served from S3:
```nginx
root /home/root2/s3bucket/public/Websites/$dep/$fac;
```

Some routes proxy back to root1:
```nginx
proxy_pass http://192.168.121.230/departments/PH/pages/...;
```

## Docker Volume Mounts

From `docker-compose.yml`, the backend container gets these bind mounts:

| Host Path (on root1) | Container Path | R/W | Purpose |
|---|---|---|---|
| `./codebase/chakra-backend/` | `/chakra-backend` | RO | Application code |
| `./codebase/chakra-backend/website` | `/website` | RW | XML/HTML content |
| `./codebase/chakra-backend/media_files` | `/media_files` | RW | Preview images, uploads |
| `./codebase/chakra-backend/static_files` | `/static_files` | RW | Generated templates |
| `./codebase/chakra-backend/reverse_proxy_configurations` | `/reverse_proxy_configurations` | RW | Generated nginx configs |
| `./codebase/chakra-backend/web_server_logs` | `/web_server_logs` | RW | Gunicorn/Daphne/Celery logs |
| `./codebase/chakra-backend/supervisor.d` | `/supervisor.d` | RW | Supervisor configs |
| `./codebase/chakra-backend/history_dir` | `/.history` | RW | Command history |
| Docker volume `static_backend` | `/static_backend` | RW | Django collectstatic output |

All containers use `network_mode: host` — no Docker networking, services bind directly on host ports.

## Process Management

Inside the `chakra-backend` Docker container, `supervisord` manages three processes:

| Process | Port | Purpose |
|---|---|---|
| Gunicorn | 8000 | Django HTTP API (5 workers, gthread, 120s timeout) |
| Daphne | 8001 | Django ASGI/WebSocket |
| Celery | — | Background task worker (RabbitMQ broker) |

Startup command: `source chakra_backend/.env && supervisord -c /supervisord.conf`

## Image Lifecycle (Current State)

This is the complete flow of how images move through the system:

### 1. Upload

```
User → POST /api/generator/image/ (chakra.channeli.in)
     → Nginx (root1) → Gunicorn → Django (generator/views/image.py)
     → Filename: sha256(str(xml_page_pk).encode('utf-8')).hexdigest() + "_" + original_name
     → Written to: /website/XML/{node}/assets/{filename}
     → Response: { value: "./assets/{filename}", key: original_name }

     File lives ONLY on root1, in the XML node's assets/ folder.
     NOT synced to root2 (lsyncd only syncs website/HTML/, not XML/).
```

### 2. Preview

```
User → GET /api/generator/preview/?xml_page_pk=123 (chakra.channeli.in)
     → Nginx (root1) → Gunicorn → Django (generator/views/preview.py)
     → Django calls Flask transpiler on localhost:5000 with write_stdout=True
     → Flask runs: ./chakra-core --write-stdout -i {CODEBASE_PATH}{xml_path} -c {components.json} ...
     → Transpiler (ImageSpec.scala) sees replaceAssets=true:
         Replaces "./assets" → "https://chakra.channeli.in/media/preview"
     → Django receives HTML string with absolute preview URLs
     → Django copies matching images:
         FROM: /website/XML/{node}/assets/{hash}_{name}
         TO:   /media_files/preview/{hash}_{name}
     → Returns HTML to user

     Preview image URL: https://chakra.channeli.in/media/preview/{hash}_{name}
     Nginx on root1 resolves /media → /media_files, so serves /media_files/preview/{hash}_{name}

     Cleanup: Celery cron (every 60min) runs tmp_clear.sh → deletes preview files older than 1 day.
```

### 3. Publish

```
XMLPage.publish() in generator/models/page.py:
     → Calls transpiler with write_stdout=False, output_path=HTML file path
     → Flask runs: ./chakra-core -i {xml_path} -o {html_path} -c {components.json} ...
     → Transpiler does NOT set replaceAssets (stays false)
     → HTML written to /website/HTML/{node}/{page}.html with "./assets" relative paths
     → Django copies images:
         FROM: /website/XML/{node}/assets/{hash}_{name}  (all matching this page's hash)
         TO:   /website/HTML/{node}/assets/{hash}_{name}
     → (First deletes existing images for this page in HTML assets/)
     → lsyncd detects changes in website/HTML/ → rsync to root2:/home/root2/new_website/

     Image now exists in THREE places:
     1. /website/XML/{node}/assets/   (source, on root1)
     2. /website/HTML/{node}/assets/  (published copy, on root1)
     3. /home/root2/new_website/...   (synced copy, on root2 — what users actually see)
```

### 4. Serving (Public Access)

```
User visits cec.iitr.ac.in/Academics/page.html
     → DNS resolves to root2 (edith)
     → Nginx on root2: root '/home/root2/new_website/cec'
     → Serves /home/root2/new_website/cec/Academics/page.html
     → HTML contains: <img src="./assets/abc123_photo.png">
     → Browser resolves relative URL → requests cec.iitr.ac.in/Academics/assets/abc123_photo.png
     → Nginx on root2 serves /home/root2/new_website/cec/Academics/assets/abc123_photo.png

     Key: published pages use RELATIVE "./assets" paths.
     Images must exist on root2's filesystem for published pages to work.
```

### 5. Image Listing (Frontend)

```
Frontend editor → GET /api/generator/image?xml_page_pk=123
     → Django scans /website/XML/{node}/assets/ directory
     → Filters by sha256 prefix matching the page PK
     → Returns list: [{ value: "./assets/hash_name.png", key: "name.png" }, ...]
     → Frontend displays in image picker dropdown
```

### 6. Image Deletion

```
Frontend editor → DELETE /api/generator/image?xml_page_pk=123&image_name=photo.png
     → Django constructs filename: sha256(page_pk) + "_" + image_name
     → Finds and deletes from /website/XML/{node}/assets/
     → NOTE: Does NOT delete from HTML assets/ — image persists in published version
       until next publish of that page
```

## Transpiler (chakra-core) Details

The transpiler is a Scala binary wrapped in a Flask API:

- **Location on root1:** `/home/root1/chakra-docker/codebase/chakra-core/`
- **Runs as:** `flask run --host=0.0.0.0 --port=5000` in tmux session
- **Binary:** `./chakra-core` (built via `sbt assembly` / `pack.sh`)
- **Config:** `components.json` (defines component CSS classes, assets_host, etc.)

### Asset Path Replacement

In `components.json` (production values):
```json
{
  "LibraryConfig": {
    "assets_host": "https://chakra.channeli.in/media/preview",
    "dummy_assets_host": "./assets",
    ...
  }
}
```

In `ImageSpec.scala` (both `Image.parseNode` and `FluidImage.parseNode`):
```scala
if (utils.replaceAssets == true) {
    src = src.replace(
        config.getLibraryConfig("dummy_assets_host"),   // "./assets"
        config.getLibraryConfig("assets_host")           // "https://chakra.channeli.in/media/preview"
    )
}
```

`replaceAssets` is only set to `true` when `writeToStdout` is `true` (`Main.scala:112-113`), which only happens during **preview**. During **publish**, HTML is written to disk with `./assets` paths intact.

## Key Environment Variables

From `chakra_backend/stencil.env` (template — actual values in `.env`):

| Variable | Example Value | Used By |
|---|---|---|
| `PERSONAL_ROOT` | `/website` | Base path for all website content |
| `XML_ROOT_URL` | `/website/XML/` | XML source content root |
| `HTML_ROOT_URL` | `/website/HTML/` | Published HTML root |
| `PREVIEW_IMAGE_PATH` | `/media_files/preview` | Where preview images are copied |
| `SERVER_URL` | `http://127.0.0.1:5000` | Flask transpiler endpoint |
| `TRANSPILER_PATH` | Path to chakra-core dir | Working directory for transpiler binary |
| `TRANSPILER_COMPONENTS_PATH` | Path to `components.json` | Transpiler component definitions |
| `SECRET_FLASK` | (secret) | Auth token for transpiler API |
| `MEDIA_ROOT` | `/media_files/` | Django media root |
| `BASE_PROTECTED_URL` | `/api/chakra_filemanager/media_files/` | Protected file access |

## Deployment Procedures

### Backend (Django)

Preferred: Jenkins job. Manual fallback:
```bash
cd /home/root1/chakra-docker/codebase/chakra-backend
git pull origin master --rebase
docker restart chakra-docker_chakra-backend_1
```

### Transpiler (chakra-core)

Preferred: Jenkins job. Manual fallback (caution: `reset --hard` wipes local `components.json` changes):
```bash
cd /home/root1/chakra-docker/codebase/chakra-core
source chakra-core-env/bin/activate
git fetch origin && git reset --hard FETCH_HEAD
./pack.sh
# Then in the tmux session, Ctrl+C and restart:
flask run --host=0.0.0.0 --port=5000
```

### Frontend (Next.js)

```bash
cd /home/root1/chakra-docker/codebase/chakra-frontend
git pull origin master --rebase
docker restart chakra-docker_chakra_frontend_1
```

### Full stack restart

```bash
cd /home/root1/chakra-docker
CURRENT_UID="$(id -u):$(id -g)" docker compose up -d
```

## Backup Strategy

| What | How | Schedule |
|---|---|---|
| Database (PostgreSQL) | `database_backup.sh` | Weekly (Sunday midnight) |
| All data | `incremental_backup_to_aws_script.sh` → S3 | Daily (3 AM) |
| Database history | S3 bucket at `/home/root1/s3bucket/chakra-backups/` | Stored in S3 |

## Key Numbers (as of 2026-04-10)

| Metric | Value |
|---|---|
| Image files in XML assets (root1) | 15,280 |
| Image files in HTML assets (root1, synced to root2) | 11,869 |
| "Orphan" images (in XML, never published to HTML) | ~3,411 |
| Total website directory (root1) | 95 GB |
| Synced content on root2 (`new_website/`) | 70 GB |
| root2 disk usage | 108 GB / 274 GB (42%) |
| Docker containers on root1 | 6 (backend, frontend, postgres, memcached, rabbitmq, libretranslate) |
| Nginx subdomain configs on root2 | 18+ |
| S3 bucket (shared backup) | Mounted on both servers |

## Local Development Setup

See [README.md](README.md) for full instructions. Quick summary:

1. `./scripts/clone.sh` — clones all repos into `./codebase/`
2. Create `.env` files from stencils (backend, core, postgres, rabbitmq)
3. Build Docker images (`./scripts/build/*.sh`)
4. `./scripts/prod.sh` — starts Docker stack + Flask transpiler
5. `python manage.py seed_website --test-page` — creates initial folder structure

Local ports: Gunicorn 8000, Daphne 8001, Next.js 3000, Flask 5000, Postgres 5432, Memcached 11211, RabbitMQ 5672.

### Key Difference from Prod

| Aspect | Local | Production |
|---|---|---|
| Nginx | Not included in docker-compose | Runs on both servers |
| lsyncd | Not needed | Syncs root1 → root2 |
| root2 | Does not exist | Separate server for public sites |
| components.json `assets_host` | Typically localhost | `https://chakra.channeli.in/media/preview` |
| SSL | Not configured | SSL certs on both servers |
| S3 | Not mounted | Mounted on both servers |
