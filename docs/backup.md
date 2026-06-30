# Backup & Restore Guide

## Backup

### Standard backup (config + certs only)

```bash
./scripts/backup.sh
```

Backs up:
- `runner/config/` — runner configuration
- `certs/` — TLS certificates
- `docker/daemon.json` — daemon configuration
- `compose.yaml` — stack definition
- `.env` — environment configuration

Output: `backups/gitlab-runner-stack_YYYYMMDD_HHMMSS.tar.gz`

### Full backup (includes data and caches)

```bash
./scripts/backup.sh --full
```

Also includes:
- `docker/data/` — Docker images, layers, build cache
- `cache/` — all language build caches

This can be very large (multiple GB). Use only when migrating to a new host.

### Retention policy

The script automatically keeps the last 10 backups and removes older ones.

## Restore

```bash
./scripts/restore.sh backups/gitlab-runner-stack_20240101_120000.tar.gz
```

The script will:
1. Ask for confirmation (overwrites existing data)
2. Stop all services
3. Extract the backup
4. Restart services

## Automation (cron)

Schedule daily backups:

```bash
# Edit crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * cd /path/to/gitlab-runner-stack && ./scripts/backup.sh
```

## What NOT to Back Up

These directories are gitignored and should not be backed up:
- `docker/data/` — large, regenerable from image pulls (use `--full` if needed)
- `cache/` — regenerable from package registries (use `--full` if needed)
- `backups/` — avoid backing up backups

## Migration to a New Host

```bash
# On old host:
./scripts/backup.sh --full

# Copy the backup to the new host:
scp backups/gitlab-runner-stack_*.tar.gz newhost:/path/to/gitlab-runner-stack/backups/

# On new host:
git clone <repo-url> gitlab-runner-stack
cd gitlab-runner-stack
./scripts/init.sh
./scripts/restore.sh backups/gitlab-runner-stack_*.tar.gz
```
