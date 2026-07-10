# Monitoring Procedure

## Project

Linux Production Support Lab v1

## Purpose

This document explains the local health check and alerting workflow for the lab application.

The monitoring script checks the application health endpoint and database health endpoint, records the result, and writes an alert when either check fails

## Health Check Endpoints

```text
http://localhost/health
http://localhost/db-health
```

## Monitoring Logs

Health check results are written to:

```text
/var/log/linux-production-support-lab-v1/monitor.log
```

Alerts are written to:

```text
/var/log/linux-production-support-lab-v1/alerts.log
```

## Manual Health Check

Run:

```bash
sudo -u prodapp /opt/linux-production-support-lab-v1/scripts/health-check.sh
```

## systemd Timer

The timer runs the health check every minute.

Check timer status:

```bash
systemctl list-timers | grep linux-production-support-lab-v1
```

Check health check service logs:

```bash
journalctl -u linux-production-support-lab-v1-healthcheck.service -n 50 --no-pager
```

## Alert Test

Stop the application:

```bash
sudo systemctl stop linux-production-support-lab-v1
```

Wait for the timer to run, or run the health check manually:

```bash
sudo -u prodapp /opt/linux-production-support-lab-v1/scripts/health-check.sh
```

Check alerts:

```bash
sudo tail -n 20 /var/log/linux-production-support-lab-v1/alerts.log
```

Start the application again:

```bash
sudo systemctl start linux-production-support-lab-v1
```

