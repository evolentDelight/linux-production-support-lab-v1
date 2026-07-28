# Production Readiness Checklist

## Project

Linux Production Support Lab v1

## Purpose

This checklist verifies that the application stack is configured, secured, monitored, recoverable, and documented before it is considered production-ready.

## Services and Startup

* [ ] The Node.js application service is active.
* [ ] The Node.js application service is enabled at boot.
* [ ] Nginx is active and enabled.
* [ ] PostgreSQL is active and enabled.
* [ ] The PostgreSQL cluster is online.
* [ ] The health-check timer is active and enabled.

## Application Health

* [ ] The application responds through Nginx at `/health`.
* [ ] The database check responds at `/db-health`.
* [ ] The ticket endpoint responds at `/tickets`.
* [ ] The Node.js application responds directly on `127.0.0.1:3000`.
* [ ] The automated health check reports `status=ok`.

## Configuration and Secrets

* [ ] The production environment file is stored under `/etc`.
* [ ] The environment file is owned by `root:prodapp`.
* [ ] The environment file has mode `640`.
* [ ] The configuration directory has mode `750`.
* [ ] Required environment variables are present.
* [ ] The real environment file is not committed to Git.

## Reverse Proxy

* [ ] The Nginx site configuration is installed.
* [ ] The Nginx site is enabled.
* [ ] `nginx -t` reports a valid configuration.
* [ ] Nginx proxies to `127.0.0.1:3000`.
* [ ] The default Nginx site is disabled.

## Logging

* [ ] Application logs are stored under `/var/log/linux-production-support-lab-v1`.
* [ ] Request and service activity is written to `app.log`.
* [ ] Application errors are written to `error.log`.
* [ ] Monitoring results are written to `monitor.log`.
* [ ] Failed health checks are written to `alerts.log`.
* [ ] The log directory has appropriate ownership and permissions.
* [ ] The logrotate configuration passes validation.

## Backup and Recovery

* [ ] The backup script exists and is executable.
* [ ] The restore script exists and is executable.
* [ ] At least one database backup exists.
* [ ] Backup files are stored under `/var/backups`.
* [ ] Backup files are not committed to Git.
* [ ] A restore test has been completed successfully.
* [ ] The backup and restore procedure is documented.

## Monitoring and Alerting

* [ ] The health-check script exists and is executable.
* [ ] The systemd health-check timer runs automatically.
* [ ] The monitor detects application failure.
* [ ] The monitor detects database failure.
* [ ] The monitoring unit does not automatically start the application being monitored.
* [ ] Recovery produces a new healthy monitoring result.

## Documentation

* [ ] The project README describes the architecture and purpose.
* [ ] Backup and restore procedures are documented.
* [ ] Monitoring procedures are documented.
* [ ] Troubleshooting drills are documented.
* [ ] Each simulated incident includes symptoms, evidence, root cause, fix, and verification.

## Repository Hygiene

* [ ] The repository contains no real credentials.
* [ ] Runtime logs are not committed.
* [ ] Database backup files are not committed.
* [ ] Deployed files under `/opt` are not committed separately.
* [ ] All completed milestone changes have been committed and pushed.

## Automated Readiness Check

Run:

```bash
sudo /opt/linux-production-support-lab-v1/scripts/readiness-check.sh
```

Resolve every reported failure before marking the system ready. Review warnings and document any accepted limitations.
