# Linux Production Support Lab Runbook

## Purpose

This runbook provides operational procedures for maintaining, validating, and troubleshooting the Linux Production Support Lab v1 application stack.

It is intended for routine service operation and first-response incident investigation.

## Architecture

```text
Client
  |
  v
Nginx on port 80
  |
  v
Node.js application on 127.0.0.1:3000
  |
  v
PostgreSQL database
```

## Components

| Component          | Purpose                                    |
| ------------------ | ------------------------------------------ |
| Nginx              | Public HTTP entry point and reverse proxy  |
| Node.js            | Application and API service                |
| PostgreSQL         | Stores application ticket data             |
| systemd            | Manages services and scheduled tasks       |
| logrotate          | Rotates and retains application logs       |
| Health-check timer | Checks application and database health     |
| Backup scripts     | Create and restore PostgreSQL data backups |

## Important Locations

| Purpose                  | Location                                                          |
| ------------------------ | ----------------------------------------------------------------- |
| Deployed application     | `/opt/linux-production-support-lab-v1`                            |
| Protected configuration  | `/etc/linux-production-support-lab-v1/app.env`                    |
| Application logs         | `/var/log/linux-production-support-lab-v1`                        |
| Nginx logs               | `/var/log/nginx`                                                  |
| Database backups         | `/var/backups/linux-production-support-lab-v1`                    |
| systemd units            | `/etc/systemd/system`                                             |
| Nginx site configuration | `/etc/nginx/sites-available/linux-production-support-lab-v1.conf` |
| Logrotate configuration  | `/etc/logrotate.d/linux-production-support-lab-v1`                |

## Service Names

```text
linux-production-support-lab-v1.service
nginx.service
postgresql.service
linux-production-support-lab-v1-healthcheck.service
linux-production-support-lab-v1-healthcheck.timer
```

## Routine Service Operations

### Check Application Status

```bash
sudo systemctl status linux-production-support-lab-v1
```

### Start the Application

```bash
sudo systemctl start linux-production-support-lab-v1
```

### Stop the Application

```bash
sudo systemctl stop linux-production-support-lab-v1
```

### Restart the Application

```bash
sudo systemctl restart linux-production-support-lab-v1
```

### Check All Main Services

```bash
sudo systemctl status linux-production-support-lab-v1
sudo systemctl status nginx
sudo systemctl status postgresql
sudo systemctl status linux-production-support-lab-v1-healthcheck.timer
```

## Health Verification

### Test Through Nginx

```bash
curl -i http://localhost/health
curl -i http://localhost/db-health
curl -i http://localhost/tickets
```

Expected healthy results:

```text
/health     -> HTTP 200 and status=ok
/db-health  -> HTTP 200 and database=connected
/tickets    -> HTTP 200 and ticket data
```

### Test Node.js Directly

```bash
curl -i http://127.0.0.1:3000/health
```

This bypasses Nginx and tests the Node.js application directly.

### Run the Monitoring Script Manually

```bash
sudo -u prodapp \
  /opt/linux-production-support-lab-v1/scripts/health-check.sh
```

Expected result:

```text
status=ok app=healthy http_code=200 database=healthy http_code=200
```

## Production Readiness Check

Run the complete environment validation:

```bash
sudo \
  /opt/linux-production-support-lab-v1/scripts/readiness-check.sh
```

Expected final result:

```text
[SUMMARY] PASS=65 WARN=0 FAIL=0
[RESULT] READY
```

## Log Locations

| Log              | Purpose                                  |
| ---------------- | ---------------------------------------- |
| `app.log`        | Application activity and request results |
| `error.log`      | Application errors and stack traces      |
| `monitor.log`    | All automated health-check results       |
| `alerts.log`     | Failed health checks                     |
| Nginx access log | Requests handled by Nginx                |
| Nginx error log  | Reverse-proxy and upstream errors        |

### View Recent Application Activity

```bash
sudo tail -n 50 \
  /var/log/linux-production-support-lab-v1/app.log
```

### View Recent Application Errors

```bash
sudo tail -n 50 \
  /var/log/linux-production-support-lab-v1/error.log
```

### View Monitoring Results

```bash
sudo tail -n 50 \
  /var/log/linux-production-support-lab-v1/monitor.log
```

### View Alerts

```bash
sudo tail -n 50 \
  /var/log/linux-production-support-lab-v1/alerts.log
```

### View Application Journal

```bash
journalctl \
  -u linux-production-support-lab-v1 \
  -n 100 \
  --no-pager
```

### View Health-Check Journal

```bash
journalctl \
  -u linux-production-support-lab-v1-healthcheck.service \
  -n 100 \
  --no-pager
```

## Database Status

Check the PostgreSQL service:

```bash
sudo systemctl status postgresql
```

Check PostgreSQL clusters:

```bash
pg_lsclusters
```

Expected cluster status:

```text
online
```

Test database connectivity through the application:

```bash
curl -i http://localhost/db-health
```

## Backup Operations

Create a backup:

```bash
sudo -u prodapp \
  /opt/linux-production-support-lab-v1/scripts/backup-db.sh
```

List available backups:

```bash
sudo ls -lh \
  /var/backups/linux-production-support-lab-v1
```

Detailed restoration instructions are located in:

```text
docs/backup-restore.md
```

Restores are destructive and should not be performed without confirming the correct backup file and expected recovery state.

## Incident Triage

When the application is reported unavailable or unhealthy, begin with the normal Nginx entry point:

```bash
curl -i http://localhost/health
```

Then use the response to narrow down the failing layer.

### Initial Triage Sequence

```bash
curl -i http://localhost/health
curl -i http://localhost/db-health
curl -i http://127.0.0.1:3000/health

sudo systemctl status nginx
sudo systemctl status linux-production-support-lab-v1
sudo systemctl status postgresql

pg_lsclusters
sudo ss -ltnp | grep -E ':80|:3000'
```

Follow this order:

1. Confirm the user-visible symptom through Nginx.
2. Test the Node.js application directly.
3. Compare `/health` with `/db-health`.
4. Check the relevant systemd service.
5. Check listening ports and configuration.
6. Review logs before applying a fix.
7. Apply the smallest appropriate recovery action.
8. Verify the complete request path afterward.

## Common Failure Patterns

### Nginx Returns 502 Bad Gateway

Typical evidence:

```text
http://localhost/health              -> HTTP 502
http://127.0.0.1:3000/health         -> connection failure or HTTP 200
```

Possible causes:

* The Node.js application is stopped.
* The Node.js application failed to start.
* Nginx points to the wrong application port.
* The application is listening on an unexpected address.

Diagnostic commands:

```bash
sudo systemctl status linux-production-support-lab-v1

journalctl \
  -u linux-production-support-lab-v1 \
  -n 100 \
  --no-pager

sudo tail -n 50 \
  /var/log/nginx/linux-production-support-lab-v1.error.log

sudo ss -ltnp | grep -E ':3000|:3999'

sudo grep -R "proxy_pass" \
  /etc/nginx/sites-enabled/
```

Recovery depends on the evidence. Do not restart the service until the likely cause has been identified.

If the application is simply stopped:

```bash
sudo systemctl start linux-production-support-lab-v1
```

### Port 80 Connection Failure

Typical evidence:

```text
http://localhost/health              -> connection refused
http://127.0.0.1:3000/health         -> HTTP 200
```

Likely cause:

```text
Nginx is unavailable while the Node.js application remains healthy.
```

Diagnostic commands:

```bash
sudo systemctl status nginx

journalctl \
  -u nginx \
  -n 100 \
  --no-pager

sudo ss -ltnp | grep ':80'
```

Recovery:

```bash
sudo nginx -t
sudo systemctl start nginx
```

Do not start or reload Nginx if `nginx -t` reports an invalid configuration.

### Basic Health Works but Database Health Fails

Typical evidence:

```text
/health       -> HTTP 200
/db-health    -> HTTP 500
/tickets      -> HTTP 500
```

Likely cause:

```text
The Node.js process is running, but PostgreSQL or database connectivity is unavailable.
```

Diagnostic commands:

```bash
sudo systemctl status postgresql
pg_lsclusters

journalctl \
  -u linux-production-support-lab-v1 \
  -n 100 \
  --no-pager

sudo tail -n 50 \
  /var/log/linux-production-support-lab-v1/error.log
```

Recovery when PostgreSQL is stopped:

```bash
sudo systemctl start postgresql
```

Then verify:

```bash
pg_lsclusters
curl -i http://localhost/db-health
curl -i http://localhost/tickets
```

### Application Service Fails to Start

Check detailed service status:

```bash
sudo systemctl status linux-production-support-lab-v1
```

Check the journal:

```bash
journalctl \
  -u linux-production-support-lab-v1 \
  -n 100 \
  --no-pager
```

Common causes include:

* Invalid environment-file syntax
* Missing or unreadable configuration
* Incorrect Node.js path
* Invalid application port
* Missing production dependencies
* Port already in use
* Incorrect deployed ownership or permissions

Useful checks:

```bash
sudo -u prodapp test \
  -r /etc/linux-production-support-lab-v1/app.env \
  && echo "app.env is readable"

sudo grep '^PORT=' \
  /etc/linux-production-support-lab-v1/app.env

command -v node
ls -l /usr/bin/node

sudo ss -ltnp | grep ':3000'

ls -ld /opt/linux-production-support-lab-v1
```

After correcting the cause:

```bash
sudo systemctl restart linux-production-support-lab-v1
```

### Monitoring Reports Critical

Review the newest monitoring results:

```bash
sudo tail -n 20 \
  /var/log/linux-production-support-lab-v1/monitor.log

sudo tail -n 20 \
  /var/log/linux-production-support-lab-v1/alerts.log
```

Check the health-check service journal:

```bash
journalctl \
  -u linux-production-support-lab-v1-healthcheck.service \
  -n 50 \
  --no-pager
```

Run the check manually:

```bash
sudo -u prodapp \
  /opt/linux-production-support-lab-v1/scripts/health-check.sh
```

A critical result identifies a symptom, not necessarily the root cause. Use the endpoint and service evidence to determine which layer failed.

## Configuration Validation

### Check Protected Configuration Permissions

```bash
ls -ld /etc/linux-production-support-lab-v1
ls -l /etc/linux-production-support-lab-v1/app.env
```

Expected:

```text
Configuration directory: root:prodapp mode 750
Environment file:        root:prodapp mode 640
```

Confirm that the service account can read the file:

```bash
sudo -u prodapp test \
  -r /etc/linux-production-support-lab-v1/app.env \
  && echo "prodapp can read app.env"
```

### Check Application Port

```bash
sudo grep '^PORT=' \
  /etc/linux-production-support-lab-v1/app.env
```

Expected:

```text
PORT=3000
```

### Check Nginx Upstream

```bash
sudo grep -R "proxy_pass" \
  /etc/nginx/sites-enabled/
```

Expected:

```text
proxy_pass http://127.0.0.1:3000;
```

### Validate Nginx Configuration

```bash
sudo nginx -t
```

Only reload Nginx after validation succeeds:

```bash
sudo systemctl reload nginx
```

## Recovery Verification

After any repair, verify the whole stack rather than only the component that failed.

Check services:

```bash
sudo systemctl status nginx
sudo systemctl status linux-production-support-lab-v1
sudo systemctl status postgresql
sudo systemctl status linux-production-support-lab-v1-healthcheck.timer
```

Check endpoints:

```bash
curl -i http://localhost/health
curl -i http://localhost/db-health
curl -i http://localhost/tickets
curl -i http://127.0.0.1:3000/health
```

Run monitoring manually:

```bash
sudo -u prodapp \
  /opt/linux-production-support-lab-v1/scripts/health-check.sh
```

Run the readiness check when the incident may have affected configuration, permissions, services, backups, or monitoring:

```bash
sudo \
  /opt/linux-production-support-lab-v1/scripts/readiness-check.sh
```

Expected final result:

```text
[RESULT] READY
```

## Troubleshooting Reference

Detailed simulated incidents and their evidence are documented in:

```text
docs/troubleshooting-drills.md
```

Use those drills as examples when comparing symptoms across the Nginx, Node.js, and PostgreSQL layers.

## Deployment Notes

The application is currently deployed manually from the development repository to:

```text
/opt/linux-production-support-lab-v1
```

The standard synchronization command is:

```bash
sudo rsync -av --delete \
  --exclude node_modules \
  --exclude .git \
  --exclude logs \
  ./ /opt/linux-production-support-lab-v1/
```

After synchronization:

```bash
sudo chown -R prodapp:prodapp \
  /opt/linux-production-support-lab-v1

sudo chmod +x \
  /opt/linux-production-support-lab-v1/scripts/*.sh
```

Install production dependencies when application dependencies have changed:

```bash
cd /opt/linux-production-support-lab-v1/app
sudo npm install --omit=dev
sudo chown -R prodapp:prodapp \
  /opt/linux-production-support-lab-v1
```

Restart the application:

```bash
sudo systemctl restart linux-production-support-lab-v1
```

Verify the deployment:

```bash
curl -i http://localhost/health
curl -i http://localhost/db-health
curl -i http://localhost/tickets

sudo -u prodapp \
  /opt/linux-production-support-lab-v1/scripts/health-check.sh
```

A complete deployment script is planned as a later project milestone. Until then, deployments should be performed carefully and verified manually.

## Post-Incident Actions

After service recovery:

1. Confirm all services and endpoints are healthy.
2. Confirm monitoring has returned to `status=ok`.
3. Record the incident timeline.
4. Preserve relevant logs and command output.
5. Document the root cause.
6. Record the recovery action.
7. Identify preventive improvements.
8. Update the runbook if the incident exposed a missing procedure.

Useful evidence sources include:

```text
systemd service status
systemd journal entries
application logs
Nginx logs
monitor and alert logs
PostgreSQL cluster status
listening ports
endpoint responses
configuration and permission metadata
```

Do not delete useful incident evidence until the cause and recovery have been documented.

## Escalation Guidance

This lab has one operator, but production systems normally have defined escalation paths.

Escalate when:

* The root cause cannot be identified safely.
* Recovery requires destructive database action.
* Data corruption or data loss is suspected.
* Credentials or secrets may have been exposed.
* The same failure repeatedly returns after recovery.
* Disk, memory, or system-resource exhaustion affects multiple services.
* A configuration change may affect systems outside the application stack.
* Recovery requires actions outside the operator’s authorization or experience.

Before escalating, provide:

```text
incident start time
affected endpoints
user-visible symptoms
service states
relevant log excerpts
commands already run
changes already attempted
current system condition
suspected failure layer
```

Avoid repeatedly restarting services without first collecting evidence. Repeated restarts can hide useful failure information.

## Known Limitations

This project currently has the following limitations:

* It runs on one Linux environment rather than multiple production servers.
* The environment is hosted in WSL rather than a dedicated production virtual machine.
* The application has no high-availability or failover configuration.
* Nginx currently serves HTTP without TLS.
* Monitoring and alerting are local only.
* Alerts are written to logs and the system journal rather than external notification systems.
* Database backups are currently initiated manually.
* Backup copies are stored on the same host.
* Backups are not currently encrypted.
* Restore testing is manual.
* Deployment is not yet handled by a complete deployment script.
* Infrastructure is not yet provisioned through Ansible or another configuration-management tool.
* Metrics, distributed traces, and centralized logging are not yet configured.
* The readiness check validates the local environment but does not replace continuous production monitoring.

These limitations should be presented honestly when discussing the project.

## Related Documentation

| Document                                 | Purpose                                                   |
| ---------------------------------------- | --------------------------------------------------------- |
| `README.md`                              | Project overview and portfolio presentation               |
| `docs/backup-restore.md`                 | Database backup and restore procedure                     |
| `docs/monitoring.md`                     | Health-check and timer operations                         |
| `docs/troubleshooting-drills.md`         | Simulated incident investigations                         |
| `docs/production-readiness-checklist.md` | Manual production-readiness requirements                  |
| `docs/runbook.md`                        | Routine operations and first-response incident procedures |

## Final Operational Verification

Run the readiness check:

```bash
sudo \
  /opt/linux-production-support-lab-v1/scripts/readiness-check.sh
```

Expected:

```text
[SUMMARY] PASS=65 WARN=0 FAIL=0
[RESULT] READY
```

Confirm Git does not contain runtime or protected files:

```bash
git status
git ls-files | grep '\.log$'
git ls-files | grep 'support_tickets_.*\.sql$'
git ls-files | grep 'app\.env$'
```

The last three commands should not show real runtime logs, backup files, or the protected production environment file.

## Runbook Maintenance

Review this runbook whenever:

* A service name or location changes.
* A new operational script is added.
* Monitoring or backup behavior changes.
* A troubleshooting drill reveals a missing procedure.
* A real or simulated incident identifies outdated guidance.
* The architecture changes.

The runbook should describe the environment that actually exists, not the environment that was originally planned.
