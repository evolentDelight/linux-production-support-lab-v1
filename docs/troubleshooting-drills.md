# Troubleshooting Drills

## Project

Linux Production Support Lab v1

## Purpose

This document records failure simulation drills used to practice diagnosing and recovering a Linux-hosted Node.js application behind Nginx with PostgreSQL.

## Troubleshooting Method

For each incident:

1. Confirm the symptom.
2. Identify which layer is failing.
3. Check service status.
4. Check logs.
5. Apply the fix.
6. Verify recovery.
7. Record the root cause.

## Drill Template

### Drill Name

#### Simulated Failure

#### User-Visible Symptom

#### Commands Used to Diagnose

#### Evidence Found

#### Root Cause

#### Fix Applied

#### Verification

#### Notes

---------------------------------

### Drill 1: Node App Service Stopped

#### Simulated Failure

Stopped the `linux-production-support-lab-v1` systemd service.

#### User-Visible Symptom

Requests through Nginx returned `502 Bad Gateway`.

#### Commands Used to Diagnose

```bash
curl -i http://localhost/health
sudo systemctl status linux-production-support-lab-v1
sudo systemctl status nginx
journalctl -u linux-production-support-lab-v1 -n 50 --no-pager
sudo tail -n 50 /var/log/nginx/linux-production-support-lab-v1.error.log
```

#### Evidence Found

Nginx was running, but the Node.js application service was stopped.

#### Root Cause

Backend application process was unavailable.

#### Fix Applied

Restarted the application service.

```bash
sudo systemctl start linux-production-support-lab-v1
```

#### Verification

`/health` and `/db-health` returned HTTP 200, and the health check returned `status=ok`

------------------------------

### Drill 2: PostgreSQL Service Stopped

#### Simulated Failure

Stopped the `postgresql` systemd service.

#### User-Visible Symptom

The basic `/health` endpoint continued to return HTTP 200, but requests for database-dependent endpoints returned 500 Internal Server Error.

#### Commands Used To Diagnose

```bash
curl -i http://localhost/health
curl -i http://localhost/db-health
curl -i http://localhost/tickets
sudo systemctl status postgresql
pg_lsclusters
journalctl -u linux-production-support-lab-v1 -n 80 --no-pager
sudo tail -n 50 /var/log/linux-production-support-lab-v1/error.log
sudo -u prodapp /opt/linux-production-support-lab-v1/scripts/health-check.sh
```

#### Evidence Found

The Nginx and Node.js App services were still running, but the PostgreSQL service was unavailable. The `/health` endpoint remained healthy while database-dependent endpoints failed.

#### Root Cause

Backend PostgreSQL service was unavailable, preventing the application from completing database queries.

#### Fix Applied

Started the PostgreSQL service

```bash
sudo systemctl start postgresql
```

#### Verification

- `pg_lsclusters` showed the PostgreSQL cluster status as `online`.
- `/health, `/db-health`, and `/tickets` returned HTTP 200.
- The health check returned `database=healthy` with `http_code=200`

### Drill 3 : Nginx stopped

#### Simulated Failure

  Stopped the `nginx` systemd service

#### User-Visible Symptom

  Requests through the normal application entry point at `http://localhost` failed because nothing was listening on port 80.


  A direct request to the Node.js application at `http://127.0.0.1/health` continued to return HTTP 200.

#### Commands Used to Diagnose

```bash
  curl -i http://localhost/
  curl -i http://localhost/health
  curl -i http://127.0.01/health
  sudo systemctl status nginx # Stated that the nginx service was inactive/dead
  sudo systemctl status linux-production-support-lab-v1 # Stated taht the service was active/running
  journalctl -u nginx -n 50 --no-pager # Logs show that the nginx service was stopped
  sudo ss -ltnp | grep ':80' # Returned no output
  sudo tail -n 50 /var/log/nginx/linux-production-support-lab-v1.error.log # Displayed nothing new, because a stopped nginx service cannot print out any error logs. (But, journalctl or systemd journal of the nginx service can present metadata info.)
```

#### Evidence Found

  The Nginx systemd service was inactive/dead, and no process was listening on port 80.


  Requests through `http://localhost/health` failed with a connection error:

  ```bash
    curl: (7) Failed to connect to localhost port 80 after 0 ms: Could not connect to server
  ```

  All while the direct request to `http://127.0.0.1:3000/health` returned HTTP 200.

  This confirmed that the Node.js application was still running and that the failure was isolated to the reverse-proxy layer.


  The Nginx error log contained no new request-related entries because Nginx was stopped and therefore did not accept or process the request. The Nginx systemd journal recorded the service stop event.

#### Root Cause

  The Nginx reverse-proxy service was unavailable, preventing clients from reaching the application through port 80.

#### Fix Applied

  Started the Nginx service:

  ```bash
    sudo systemctl start nginx
  ```

#### Verification

  - `sudo systemctl status nginx` showed the service was active (running).
  - `sudo ss -ltnp | grep ':80'` showed Nginx listening on port 80.
  - `http://localhost/health` returned HTTP 200.
  - `http://127.0.0.1:3000/health` continued to return HTTP 200.
  - The health-check script returned `status=ok`

---------------------------------

### Drill 4: Nginx-to-Application Port Mismatch

#### Simulated Failure

  Changed the Node.js application from `3000` to `3999` while leaving Nginx configured to proxy requests to `127.0.0.1:3000`

#### User-Visible Symptom

  Requests through Nginx returned `HTTP 502 Bad Gateway`. Direct requests to the application on port `3999` returned HTTP 200.

#### Commands Used to Diagnose

  ```bash
    curl -i http://localhost/health
    curl -i http://127.0.0.1:3000/health
    curl -i http://127.0.0.1:3999/health
    sudo systemctl status linux-production-support-lab-v1
    journalctl -u linux-production-support-lab-v1 -n 50 --no-pager
    sudo ss -ltnp | grep -E ':3000|:3999'
    sudo grep -R "proxy_pass" /etc/nginx/sites-enabled/
    sudo tail -n 50 /var/log/nginx/linux-production-support-lab-v1.error.log
    sudo -u prodapp /opt/linux-production-support-lab-v1/scripts/health-check.sh
  ```

#### Evidence Found

  Nginx and the Node.js application were both running. The Node.js application was listening on port `3999`, while Nginx was still configured to proxy requests to port `3000`.


  Requests through Nginx returned `HTTP 502`, while direct requests to port `3999` returned `HTTP 200`.

#### Root Cause

  The application and Nginx configurations specified different backend ports.

#### Fix Applied

  Restored `PORT=3000` in the protected application environment file and restarted the Node.js service.

  ```bash
    sudo systemctl restart linux-production-support-lab-v1
  ```

#### Verification

  - The Node.js application listened on `127.0.0.1:3000`.
  - Requests through the Nginx returned `HTTP 200`.
  - `/health`, `/db-health`, and `/tickets` responded successfully.
  - The health-check script returned `status=ok`.

#### Notes

---------------------------------

## System Comparison

| Failure | `curl localhost/health` | `curl 127.0.0.1:3000/health` | Likely Layer |
|---|---:|---:|---|
| App stopped | 502 | Connection refused | Node app |
| PostgreSQL stopped | 200 for `/health`, failure for `/db-health` | Same | Database |
| Nginx stopped | Connection refused | 200 | Nginx |
| Port mismatch | 502 | Depends on the actul app port | Nginx/app config |