# Postmortem: Nginx-to-Application Port Mismatch

## Incident Summary

The Linux Production Support Lab application became unavailable through its normal Nginx entry point after the Node.js application port was changed from `3000` to `3999`.

The Node.js application remained operational, but Nginx continued forwarding requests to `127.0.0.1:3000`. This configuration mismatch caused requests through Nginx to return HTTP 502 Bad Gateway.

## Impact

Users could not access the application through:

```text
http://localhost
```

The following endpoints were unavailable through Nginx:

```text
/health
/db-health
/tickets
```

The Node.js application itself remained available directly at:

```text
http://127.0.0.1:3999
```

No data loss or database corruption occurred.

## Detection

The incident was detected through:

* HTTP 502 responses from Nginx.
* The automated health-check script reporting `status=critical`.
* Entries written to `monitor.log` and `alerts.log`.
* Direct comparison between the Nginx endpoint and the Node.js endpoint.

## Timeline

| Event                 | Description                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------ |
| Incident introduced   | The application environment file was changed from `PORT=3000` to `PORT=3999`.                                |
| Application restarted | The Node.js service loaded the new port and began listening on `127.0.0.1:3999`.                             |
| Failure detected      | Requests through Nginx returned HTTP 502 Bad Gateway.                                                        |
| Initial investigation | Nginx and the Node.js systemd services were confirmed active.                                                |
| Evidence collected    | Listening-port checks showed Node.js on port `3999`, while Nginx configuration still referenced port `3000`. |
| Root cause identified | The application and reverse-proxy configurations used different ports.                                       |
| Resolution applied    | The environment file was restored to `PORT=3000`, and the Node.js service was restarted.                     |
| Recovery verified     | Nginx and direct application endpoints returned HTTP 200, and monitoring returned `status=ok`.               |

## Technical Evidence

Requests through Nginx failed:

```bash
curl -i http://localhost/health
```

Result:

```text
HTTP/1.1 502 Bad Gateway
```

The original application port was unavailable:

```bash
curl -i http://127.0.0.1:3000/health
```

The application responded successfully on the changed port:

```bash
curl -i http://127.0.0.1:3999/health
```

Listening-port inspection showed the Node.js process on port `3999`:

```bash
sudo ss -ltnp | grep -E ':3000|:3999'
```

The application environment contained:

```text
PORT=3999
```

The Nginx site configuration still contained:

```nginx
proxy_pass http://127.0.0.1:3000;
```

## Root Cause

The Node.js application and Nginx reverse proxy were configured to use different backend ports.

The application listened on:

```text
127.0.0.1:3999
```

Nginx attempted to connect to:

```text
127.0.0.1:3000
```

Because no process was listening on port `3000`, Nginx could not connect to its upstream application and returned HTTP 502.

## Contributing Factors

* The application and Nginx port values were defined in separate configuration files.
* There was no automated deployment validation confirming that both configurations referenced the same port.
* The configuration change was applied directly to the protected environment file.
* The application service restart successfully loaded the new configuration, making the application appear healthy when checked only through systemd.
* Nginx service status alone did not reveal the upstream mismatch.

## Resolution

The original environment configuration was restored:

```text
PORT=3000
```

The Node.js service was restarted:

```bash
sudo systemctl restart linux-production-support-lab-v1
```

No Nginx change was required because its upstream configuration already pointed to the intended application port.

## Recovery Verification

The following checks succeeded after recovery:

```bash
curl -i http://localhost/health
curl -i http://localhost/db-health
curl -i http://localhost/tickets
curl -i http://127.0.0.1:3000/health
```

The health-check script returned:

```text
status=ok app=healthy http_code=200 database=healthy http_code=200
```

The production-readiness check returned:

```text
[RESULT] READY
```

## What Went Well

* The health-check script detected the outage.
* Monitoring and alert logs preserved evidence of the failure.
* Direct testing of the Node.js port helped isolate the problem from Nginx.
* `ss` clearly showed the application’s actual listening port.
* The Nginx configuration could be inspected without changing it.
* The original environment file had been backed up before the drill.
* Recovery required only restoring the expected port and restarting the application.

## What Could Be Improved

* Configuration consistency was not validated before restarting the application.
* The deployment process was manual and did not include an automated smoke test.
* The port was duplicated across the application environment and Nginx configuration.
* No automated check compared the application port with the Nginx upstream port before deployment.
* Incident evidence collection required several separate manual commands.

## Corrective and Preventive Actions

| Action                                                           | Status               |
| ---------------------------------------------------------------- | -------------------- |
| Validate `PORT=3000` in the production-readiness script          | Completed            |
| Validate that Nginx proxies to `127.0.0.1:3000`                  | Completed            |
| Document the port-mismatch troubleshooting procedure             | Completed            |
| Include full endpoint verification after configuration changes   | Completed            |
| Add a complete deployment script with preflight and smoke checks | Planned              |
| Add automated incident-evidence collection                       | Planned              |
| Consider reducing duplicated configuration values                | Future consideration |

## Lessons Learned

A service being active does not necessarily mean that the full application path is operational.

Troubleshooting required testing each layer independently:

```text
Nginx entry point
Node.js listening port
Application configuration
Nginx upstream configuration
```

The most useful diagnostic evidence came from comparing the expected configuration with the actual listening socket.

## Blameless Statement

The incident resulted from a configuration mismatch introduced during a controlled troubleshooting exercise. The purpose of this postmortem is to improve validation, deployment, monitoring, and recovery procedures rather than assign individual blame.
