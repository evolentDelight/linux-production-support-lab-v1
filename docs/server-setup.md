# Server Setup

## Project

Linux Production Support Lab v1

## Purpose

This document records the Linux server setup used to deploy and operate the lab application in a production environment.

## Server Environment

- OS: Ubuntu 26.04 LTS
- Runtime: Node.js
- App location: `/opt/linux-production-support-lab-v1`
- Log location: `/var/log/linux-production-support-lab-v1`
- Config location: `/etc/linux-production-support-lab-v1`
- Backup location: `/var/backups/linux-production-support-lab-v1`
- Service user: `prodapp`

## Baseline Packages

Installed packages:

```bash
git
curl
tree
rsync
build-essential
lsb-release