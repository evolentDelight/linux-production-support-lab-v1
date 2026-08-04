# Linux Production Support Lab

A production-style Linux operations lab for deploying, operating, monitoring, troubleshooting, and recovering a Node.js application backed by PostgreSQL.

## Project Overview

This project models a small application stack running on Ubuntu Linux:

```text
Client
  |
  v
Nginx :80
  |
  v
Node.js application 127.0.0.1:3000
  |
  v
PostgreSQL
```

The environment includes:

* Nginx reverse proxying
* A systemd-managed Node.js application
* PostgreSQL application data
* Protected environment configuration
* Structured application logging
* Log rotation
* Automated health monitoring
* Database backup and restore procedures
* Production-readiness validation
* Controlled troubleshooting drills
* An operations runbook
* A blameless incident postmortem

## Technology Stack

| Technology     | Purpose                              |
| -------------- | ------------------------------------ |
| Ubuntu Linux   | Application host environment         |
| Node.js        | Application and API runtime          |
| PostgreSQL     | Relational database                  |
| Nginx          | Reverse proxy and HTTP entry point   |
| systemd        | Service and timer management         |
| Bash           | Operational scripting and automation |
| logrotate      | Log rotation and retention           |
| Git and GitHub | Source control and documentation     |

## Architecture

Requests enter through Nginx on port `80`.

Nginx forwards application traffic to the Node.js process at:

```text
127.0.0.1:3000
```

The Node.js application connects to PostgreSQL for database-dependent requests.

The application binds only to the loopback interface, so Nginx remains the normal user-facing entry point.

## Operational Capabilities

### Application Endpoints

| Endpoint     | Purpose                                          |
| ------------ | ------------------------------------------------ |
| `/health`    | Confirms that the Node.js application is running |
| `/db-health` | Confirms application-to-database connectivity    |
| `/tickets`   | Returns support-ticket data from PostgreSQL      |
| `/error`     | Generates a controlled error for logging tests   |

Example checks:

```bash
curl http://localhost/health
curl http://localhost/db-health
curl http://localhost/tickets
```

### Service Management

The Node.js application is managed by:

```text
linux-production-support-lab-v1.service
```

The service:

* Runs under the dedicated `prodapp` account
* Loads protected configuration from `/etc`
* Uses `/usr/bin/node`
* Restarts after unexpected failures
* Starts after PostgreSQL and the network
* Uses systemd security restrictions

Example status check:

```bash
sudo systemctl status linux-production-support-lab-v1
```

### PostgreSQL Integration

The application uses:

```text
Database: production_support_lab_v1
Table:    public.support_tickets
```

Database health is checked through the application using:

```text
/db-health
```

This verifies that both the Node.js process and its PostgreSQL connection are operational.

### Logging

Application and monitoring logs are stored under:

```text
/var/log/linux-production-support-lab-v1
```

| File          | Purpose                         |
| ------------- | ------------------------------- |
| `app.log`     | Structured application activity |
| `error.log`   | Application errors              |
| `monitor.log` | Automated health-check results  |
| `alerts.log`  | Failed health checks            |

Application logs are managed through logrotate.

### Monitoring

The health-check script validates:

* Application health through Nginx
* Database connectivity through the application
* HTTP status codes
* Expected JSON response bodies

Automated monitoring runs through:

```text
linux-production-support-lab-v1-healthcheck.service
linux-production-support-lab-v1-healthcheck.timer
```

Healthy checks are written to `monitor.log`. Failed checks are also written to `alerts.log`.

### Backup and Restore

The project includes scripts for:

* Creating PostgreSQL data backups
* Restoring from a selected backup
* Requiring explicit restore confirmation
* Preserving backup ownership and permissions

Backups are stored under:

```text
/var/backups/linux-production-support-lab-v1
```

Backup and restore behavior was verified by:

1. Backing up three support-ticket rows.
2. Adding a fourth row.
3. Restoring the backup.
4. Confirming that the table returned to three rows.

See [`docs/backup-restore.md`](docs/backup-restore.md) for the complete procedure.

## Production-Style Filesystem Layout

| Purpose                 | Location                                       |
| ----------------------- | ---------------------------------------------- |
| Application files       | `/opt/linux-production-support-lab-v1`         |
| Protected configuration | `/etc/linux-production-support-lab-v1/app.env` |
| Application logs        | `/var/log/linux-production-support-lab-v1`     |
| Database backups        | `/var/backups/linux-production-support-lab-v1` |
| systemd units           | `/etc/systemd/system`                          |
| Nginx configuration     | `/etc/nginx`                                   |
| Logrotate configuration | `/etc/logrotate.d`                             |

The application runs under the dedicated non-root service account:

```text
prodapp
```

## Repository Structure

```text
.
├── .gitignore
├── README.md
├── app
│   ├── .env.example
│   ├── package-lock.json
│   ├── package.json
│   └── src
│       ├── config.js
│       ├── db.js
│       ├── logger.js
│       └── server.js
├── docs
│   ├── backup-restore.md
│   ├── monitoring.md
│   ├── postmortems
│   │   └── nginx-port-mismatch.md
│   ├── production-readiness-checklist.md
│   ├── runbook.md
│   ├── server-setup.md
│   └── troubleshooting-drills.md
├── infra
│   ├── logrotate
│   │   └── linux-production-support-lab-v1
│   ├── nginx
│   │   └── linux-production-support-lab-v1.conf
│   ├── postgres
│   │   └── schema.sql
│   └── systemd
│       ├── linux-production-support-lab-v1-healthcheck.service
│       ├── linux-production-support-lab-v1-healthcheck.timer
│       └── linux-production-support-lab-v1.service
├── logs
│   └── .gitkeep
└── scripts
    ├── backup-db.sh
    ├── health-check.sh
    ├── readiness-check.sh
    └── restore-db.sh
```

## Production Readiness

The automated readiness script validates:

* Required commands
* Service status
* PostgreSQL availability
* Application endpoints
* Configuration files
* File ownership and permissions
* Nginx configuration
* Logging and logrotate
* Operational scripts
* Backup availability and freshness
* Monitoring services
* Project documentation

Run it with:

```bash
sudo \
  /opt/linux-production-support-lab-v1/scripts/readiness-check.sh
```

Latest validated result:

```text
[SUMMARY] PASS=67 WARN=0 FAIL=0
[RESULT] READY
```

## Troubleshooting and Incident Response

The project includes controlled troubleshooting drills across the proxy, application, and database layers.

| Incident               | Observed behavior                                                       | Diagnostic lesson                                                             |
| ---------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Node.js service outage | Nginx returned HTTP 502                                                 | An active proxy does not guarantee that its upstream application is available |
| PostgreSQL outage      | `/health` remained healthy while database-dependent endpoints failed    | Application health and dependency health must be checked separately           |
| Nginx outage           | Port 80 refused connections while Node.js remained healthy on port 3000 | Direct backend testing can isolate a reverse-proxy failure                    |
| Port mismatch          | Node.js listened on port 3999 while Nginx forwarded to port 3000        | Service status alone does not reveal configuration mismatches                 |

The troubleshooting process follows a layered approach:

```text
Nginx entry point
  |
  v
Node.js process and listening port
  |
  v
Application configuration
  |
  v
PostgreSQL availability
```

The project also includes:

* An operator runbook for routine operations and first-response investigation
* A blameless postmortem covering the Nginx-to-application port mismatch
* Recovery verification across Nginx, Node.js, PostgreSQL, monitoring, and readiness checks

## Documentation

| Document                                                                             | Purpose                                  |
| ------------------------------------------------------------------------------------ | ---------------------------------------- |
| [`docs/server-setup.md`](docs/server-setup.md)                                       | Initial server setup                     |
| [`docs/runbook.md`](docs/runbook.md)                                                 | Routine operations and incident response |
| [`docs/monitoring.md`](docs/monitoring.md)                                           | Health monitoring procedures             |
| [`docs/backup-restore.md`](docs/backup-restore.md)                                   | Database backup and recovery             |
| [`docs/troubleshooting-drills.md`](docs/troubleshooting-drills.md)                   | Controlled failure exercises             |
| [`docs/production-readiness-checklist.md`](docs/production-readiness-checklist.md)   | Manual readiness review                  |
| [`docs/postmortems/nginx-port-mismatch.md`](docs/postmortems/nginx-port-mismatch.md) | Blameless incident analysis              |

## Security and Operational Practices

The project applies several production-oriented practices:

* Dedicated non-root service account
* Protected environment configuration
* Least-privilege file permissions
* Node.js bound to the loopback interface
* Nginx used as the application entry point
* systemd service hardening
* Secrets excluded from Git
* Runtime logs excluded from Git
* Database backups excluded from Git
* Explicit restore confirmation
* Evidence collection before remediation
* Full-stack verification after recovery

## Known Limitations

This is a single-host learning environment rather than a complete production platform.

Current limitations include:

* Hosted in WSL rather than a dedicated server or cloud VM
* No high availability or failover
* No TLS configuration
* Local-only monitoring and alerting
* Backups stored on the same host
* Backups currently initiated manually
* No centralized logging
* No metrics dashboard or distributed tracing
* No complete automated deployment workflow
* No infrastructure provisioning through configuration management
* No external secret-management platform

These limitations are documented rather than hidden and provide opportunities for future development.

## Planned Phase 2 Enhancements

* **Milestone 15 — Deployment automation:** Controlled deployment with preflight validation, repository synchronization, dependency installation, permission restoration, service restart, smoke testing, and rollback preparation.
* **Milestone 16 — Scheduled backups and retention:** Automated PostgreSQL backups using a systemd service and timer, with backup validation, retention cleanup, logging, failure detection, and freshness checks.
* **Milestone 17 — Incident evidence collection:** Read-only collection of service states, journal entries, listening ports, endpoint responses, PostgreSQL status, resource usage, recent errors, monitoring state, and backup freshness.

## Skills Demonstrated

* Linux filesystem layout, users, groups, permissions, and service accounts
* Node.js application operations
* PostgreSQL administration and recovery
* Nginx reverse-proxy configuration
* systemd services and timers
* Bash operational scripting
* Structured logging and log rotation
* Health monitoring and readiness validation
* Layered incident troubleshooting
* Database backup and restore
* Runbook development
* Blameless postmortem documentation
* Git-based project organization

## Project Status

The core application, infrastructure, monitoring, backup, troubleshooting, readiness, runbook, and postmortem milestones are complete.

The deployed environment currently passes automated production-readiness validation:

```text
PASS=67
WARN=0
FAIL=0
RESULT=READY
```

Phase 2 operational automation is planned next.
