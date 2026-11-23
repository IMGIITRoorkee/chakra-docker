# Chakra staging runbook

Staging is a copy of the production Chakra app server for testing branches and data.
It is isolated: no lsyncd, no tunnel to root2, Elasticsearch and SMTP point at closed local ports, and the security group blocks the Channeli servers and production.
Publishing here only writes HTML under `~/chakra-docker/codebase/chakra-backend/website/HTML/`.

## Layout

- Compose project `~/chakra-docker` (same compose file as prod) plus the staging `docker-compose.override.yml`.
- Code checkouts in `~/chakra-docker/codebase/{chakra-backend,chakra-frontend,chakra-core}`, remote `https://github.com/IMGIITRoorkee/<repo>` with no credentials.
- Containers keep prod's names (`chakra-docker_chakra-backend_1`, ...) so prod commands work unchanged.
- The transpiler runs in the `chakra-core` container (Python 3.6 + Java 11, image built from `~/chakra-staging/images/core.Dockerfile`), not in tmux: Ubuntu 26.04 has no Python 3.6.
- The jar is still built on the host with `pack.sh` (OpenJDK 11 and sbt from coursier in `~/.local/share/coursier/bin`), exactly as on prod.
- Staging build and setup files live in `~/chakra-staging/`; `refresh-db.sh`, `counts.sql` and `mk_html_dirs.py` there come from `ops/staging/` (`ops/install.sh staging`).
- Its hostname has no DNS record; the certificate in `/etc/ssl/chakra-staging/` is self-signed.
  From the campus network: `curl -k --resolve <staging-host>:443:<staging-ip> https://<staging-host>/login/`, or add the name to `/etc/hosts`.

## Smoke test

```bash
cd ~/chakra-docker && CHAKRA_HOST=<staging-host> bash scripts/smoke.sh
```

It must print 7 `ok` lines.

## Restart

```bash
cd ~/chakra-docker
docker compose up -d                                 # start anything that is down
docker restart chakra-docker_chakra-backend_1        # backend (gunicorn, daphne, celery)
docker restart chakra-docker_chakra_frontend_1       # frontend (rebuilds if sources changed)
docker restart chakra-core                           # transpiler
```

## Deploy a branch by bundle

On the Mac (the server has no GitHub credentials):

```bash
cd ~/Developer/chakra/chakra-backend && git fetch origin
git bundle create /tmp/chakra-backend.bundle refs/remotes/origin/<branch>
scp /tmp/chakra-backend.bundle chakra-staging:bundles/
```

On staging:

```bash
cd ~/chakra-docker/codebase/chakra-backend
git fetch ~/bundles/chakra-backend.bundle refs/remotes/origin/<branch>:refs/remotes/origin/<branch>
git checkout -B <branch> origin/<branch>
```

Go back to master with `git checkout master && git merge --ff-only origin/master` after fetching a master bundle the same way.
Then restart what changed:

- backend: `docker restart chakra-docker_chakra-backend_1`; run `python manage.py migrate` in it if the branch adds migrations.
- frontend: `docker restart chakra-docker_chakra_frontend_1` and wait for `yarn build` (`docker logs -f chakra-docker_chakra_frontend_1`); if `yarn.lock` changed, first run
  `docker run --rm -u 1000:1000 -e HOME=/tmp -v ~/chakra-docker/codebase/chakra-frontend:/chakra-frontend chakra-frontend:latest yarn install --frozen-lockfile`.
- core: `cd ~/chakra-docker/codebase/chakra-core && PATH=$PATH:~/.local/share/coursier/bin ./pack.sh && docker restart chakra-core`.
- `requirements.txt` or a Dockerfile changed: `~/chakra-staging/images/build-images.sh && cd ~/chakra-docker && docker compose up -d`.

Core `components.json` is skip-worktree and holds the staging LibraryConfig.
If a branch changes it, `git update-index --no-skip-worktree components.json`, `git checkout components.json`, check out the branch, then re-merge the config:

```bash
cd ~/chakra-docker/codebase/chakra-core
jq --slurpfile lib ~/chakra-core-libraryconfig.json '.LibraryConfig = $lib[0]' components.json > /tmp/c.json && cat /tmp/c.json > components.json
git update-index --skip-worktree components.json
~/chakra-env-guard.sh snapshot
```

Run the smoke test after every deploy.

## Refresh the database from the latest backup

```bash
~/chakra-staging/refresh-db.sh                 # newest $BACKUP_BUCKET/db/**/chakradb-*.sql.gz
~/chakra-staging/refresh-db.sh db/2026/11/chakradb-2026-11-23T1215Z.sql.gz   # a specific dump
```

It stops the backend and frontend, recreates `chakradb`, restores the dump, prints row counts, restarts them and recreates the HTML folder tree.
Compare the counts with prod using the same `~/chakra-staging/counts.sql` (read-only `psql` on prod).

## Refresh content

```bash
B=~/chakra-docker/codebase/chakra-backend
. ~/chakra-ops/ops.env
aws s3 sync --only-show-errors $BACKUP_BUCKET/files/website/XML/ $B/website/XML/
aws s3 sync --only-show-errors $BACKUP_BUCKET/files/media_files/ $B/media_files/
aws s3 sync --only-show-errors $BACKUP_BUCKET/files/reverse_proxy_configurations/ $B/reverse_proxy_configurations/
```

`website/HTML` and `website/JoshUsers` are not copied (disk); publishes write fresh HTML locally.
The HTML folder tree is created from the `Folder` rows by `mk_html_dirs.py` (refresh-db.sh runs it).

## Testing as an editor

Channeli OAuth has no app for this hostname, so the login button does not work.
To call the API as an editor, mint a signed session cookie for a Chakra admin:

```bash
docker exec -i chakra-docker_chakra-backend_1 bash -c 'source chakra_backend/.env && python manage.py shell' < ~/chakra-staging/e2e_session.py
K=$(cat ~/chakra-docker/codebase/chakra-backend/web_server_logs/staging-e2e.session)
curl -sk --resolve <staging-host>:443:127.0.0.1 -b "chakra_session=$K" 'https://<staging-host>/generator/preview/?xml_page_pk=7335'
```

`~/chakra-staging/e2e_publish.py` republishes page 7335 the same way as the editor's publish.

## Server-only config

Locked by `~/chakra-env-guard.sh` like prod (snapshots go to `$BACKUP_BUCKET/staging/env/`).
To change one: `~/chakra-env-guard.sh unlock`, copy the old file to `~/chakra-env-backup/<date>-<reason>/`, edit, then `snapshot`, `lock`, `check`.
All secrets were generated on this server by `~/chakra-staging/gen-config.sh` and are unique to staging; never copy prod values here.
Never print them: mask with `sed -E 's/=.*/=<masked>/'` when inspecting env files.

## Logs and monitoring

- Backend: `~/chakra-docker/codebase/chakra-backend/web_server_logs/` (rotated by `/etc/logrotate.d/chakra`).
- Transpiler: `docker logs chakra-core`.
- nginx: `/var/log/nginx/chakra-*.log`.
- Docker logs capped at 50 MB x 5 (`/etc/docker/daemon.json`).
- CloudWatch agent (`/opt/aws/amazon-cloudwatch-agent/etc/chakra-cloudwatch.json`): memory, swap, disk, CPU with `InstanceName=chakra-staging`.
