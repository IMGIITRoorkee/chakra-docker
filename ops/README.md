# Chakra operations scripts

Everything that runs on the Chakra servers outside the containers: backups, health checks, config guards, content sync, tunnels and the root2 replica.
Each server has one role, and `install.sh` installs that role's files.
No server-specific value lives in this repo: hosts, buckets and key paths come from a config file on each server.

## Roles

| Role | Server | What runs | When |
| --- | --- | --- | --- |
| `app-server` | Production Chakra app server | `chakra-backup.sh db` | cron, every 6 hours at :15 |
| | | `chakra-backup.sh files` | cron, daily at 21:30 |
| | | `chakra-health.sh` | cron, every 5 minutes |
| | | `chakra-env-guard.sh` | by hand, and `check` from the health job |
| | | lsyncd (`lsyncd-chakra.service`, `lsyncd.conf.lua`) | always on |
| | | CloudWatch agent (`cloudwatch.json`), logrotate | always on, daily |
| `replica` | AWS replica of root2 | `replica-nginx-watch.service`, which runs `replica-nginx-apply.sh` | 10 s after each nginx push |
| | | `replica-health.sh` | cron, every 5 minutes |
| | | `backup-root2-nginx.sh` | cron, daily at 21:45 |
| | | s3fs mount of the faculty bucket, logrotate | always on, daily |
| `web-server` | root2, the public web server | `aws-tunnel.sh` | cron, at boot and every 5 minutes |
| | | `push-nginx.sh` | cron, every 5 minutes |
| `jump-host` | Jump host inside the campus network | `prod-to-replica.sh` | cron, at boot and every 5 minutes |
| `staging` | Staging copy of the app server | `chakra-env-guard.sh`, `refresh-db.sh` | by hand |

Cron times are in the server's time zone.
`lib/` holds the code the roles share: config loading (`common.sh`), CloudWatch health reporting (`health.sh`) and the reverse tunnel loop (`reverse-tunnel.sh`).
`staging/README.md` is the staging runbook.

## How content and config move

lsyncd on the app server pushes published HTML, Josh Users sites and ConfMan nginx configs to root2 and to the replica.
Neither target is reachable from the app server directly, so each push goes through a reverse SSH tunnel that ends on the app server: root2 opens one (`aws-tunnel.sh`), and the jump host opens the one to the replica (`prod-to-replica.sh`).
root2 also pushes its whole nginx config to the replica every 5 minutes (`push-nginx.sh`).
The replica applies that config only if `nginx -t` passes, and otherwise keeps the last good one.

## Health checks

`chakra-health.sh` and `replica-health.sh` publish one CloudWatch metric per check in the `Chakra/Health` namespace, plus `AllOk`, with an `InstanceId` dimension.
Each run also appends one line to its log, for example `2026-11-23T19:20:02Z all_ok=1 db_age_h=1 files_age_h=1 disk=74% failed: none`.

## Configuration

Every script reads `~/chakra-ops/ops.env`, which is never committed.
Start from `ops.env.example`, keep only the values the role needs, and `chmod 600` it.
A script whose value is missing stops with a message naming the value and the file.

| Value | Roles |
| --- | --- |
| `AWS_BIN`, `AWS_REGION`, `BACKUP_BUCKET` | app-server, replica, staging |
| `ROOT2_TUNNEL_PORT` | app-server, web-server |
| `REPLICA_TUNNEL_PORT` | app-server, jump-host |
| `CHAKRA_HOST`, `LSYNCD_ROOT2_KEY`, `LSYNCD_REPLICA_KEY` | app-server |
| `GUARD_S3_PREFIX`, `GUARD_EXTRA_TRACKED` | app-server, staging |
| `SITE_HOST`, `FACSPACE_BUCKET` | replica |
| `ROOT2_TUNNEL_DEST`, `ROOT2_TUNNEL_KEY`, `REPLICA_PUSH_DEST`, `REPLICA_PUSH_KEY` | web-server |
| `APP_SERVER_SSH_DEST`, `REPLICA_SSH_ADDR` | jump-host |

## Installing

Run the installer as the role's normal user (`ubuntu` on the AWS servers, `root2` on root2, `apps` on the jump host); it uses `sudo` only for system files.
The servers have no GitHub credentials, so copy `ops/` over (for example with `scp -r`) and then:

```bash
ops/install.sh <role> --dry-run   # prints every step and whether it is new, changed or unchanged
ops/install.sh <role>
```

The installer:

- copies `ops/` to `~/chakra-ops/` (leaving `ops.env` alone) and points each script's usual path at that copy with a symlink, keeping a file it replaces as `<name>.pre-ops`;
- installs systemd units, logrotate files, the lsyncd config and root-run scripts with `sudo`, and restarts or reloads the service when one changed;
- writes the role's cron entries into a `# BEGIN chakra-ops <role>` block in the user's crontab and drops older copies of the same lines;
- refuses to link a script before every value it needs is in `ops.env`.

Re-running it changes nothing when nothing changed.
After installing `app-server`, run `~/chakra-env-guard.sh snapshot`, because the guard also tracks the lsyncd config.
A tunnel that is already running keeps its old code until it reconnects or the server reboots.

## Bootstrapping a new server

`bootstrap.sh staging|replica` installs the base packages, swap, the AWS CLI and the CloudWatch agent on a fresh Ubuntu instance.
Run it once before `install.sh`.

## Tests

```bash
bash ops/tests/run.sh
```

The tests need bash 4.3 or newer and `flock`, and stub every external command.
CI runs them together with `shellcheck`, `bash -n` and `install.sh <role> --dry-run` for every role against `ops.env.example`.
