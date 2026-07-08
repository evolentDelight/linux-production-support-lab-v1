# Backup and Restore Procedure

## Project

Linux Production Support Lab v1

## Purpose

This document describes how to back up and restore the PostgreSQL `support_tickets` table used by the application.

This procedure is for operational recovery workflow for the Linux Production Support Lab

## Backup Location

Backups are stored in:

```text
/var/backups/linux-production-support-lab-v1

Backup files follow this naming pattern:

```text
support_tickets_YYYYMMDD_HHMMSS.sql
```

Example:

```text
support_tickets_20260708_143812.sql
```

## Create a Backup

Run the backup script as the prodapp service user:

```bash
sudo -u prodapp /opt/linux-production-support-lab-v1/scripts/backup-db.sh
```

Expected result:

```text
[INFO] Creating backup: /var/backups/linux-production-support-lab-v1/support_tickets_YYYYMMDD_HHMMSS.sql
[INFO] Backup completed successfully
[INFO] Backup file: /var/backups/linux-production-support-lab-v1/support_tickets_YYYYMMDD_HHMMSS.sql
```

## Restore Backup

1. Stop the application:

```bash
sudo systemctl stop linux-production-support-lab-v1
```

2. Restore from a backup

```bash
sudo -u prodapp /opt/linux-production-suppolrt-lab-v1/scripts-db.sh "<$BackupPath>" --yes
```

3. Start the application

```bash
sudo systemctl start linux-production-support-lab-v1
```