
---

# Testing checklist (before you submit)
1. Confirm SSH connectivity: `ssh -i ~/.ssh/id_rsa user@server`  
2. Ensure remote server has free disk space and sudo.  
3. Ensure firewall/security group allows port 80 (or test that `curl` via SSH works).  
4. On first run, watch the log: `tail -f deploy_YYYYMMDD_HHMMSS.log`.  
5. After script completes, verify on remote server:
   - `sudo docker ps` shows `deployed_app` container running.
   - `sudo systemctl status nginx` is active.
   - `sudo nginx -T | grep deployed_app` shows the config.
6. From your laptop, `curl -I http://<server-ip>/` should return HTTP 200/301/whatever.

---

# Troubleshooting tips
- `Permission denied (publickey)`: ensure the SSH key matches the authorized_keys on the server, and the key has correct permissions (`chmod 600` in Git Bash).  
- `ssh: connect to host x.x.x.x port 22: Connection timed out`: check server is reachable and port 22 allowed by firewall/security group.  
- `External HTTP check failed`: check UFW or cloud security group allows port 80; check Nginx logs `/var/log/nginx/error.log`.  
- `docker build` failed: inspect remote build logs `/var/log/syslog` or re-run build manually via SSH: `cd /home/ubuntu/app_deploy && sudo docker build .`

---

# Notes on improvements you can add (optional)
- Add email/Slack notifications on success/failure.  
- Add support for Let's Encrypt (Certbot) to enable HTTPS automatically (requires domain and open port 80/443).  
- Support passing all parameters as environment variables for CI/CD.  
- Add healthcheck endpoint parsing (check for HTTP 200 from `/health` if such exists).  
- Add systemd-unit generation to manage docker-compose stacks via systemd.

---

# Windows-specific gotchas (Git Bash)
- Use forward slashes for paths (e.g., `~/.ssh/id_rsa`). Git Bash will translate.
- If `rsync` isn't present, Git Bash sometimes bundles it; otherwise the script will use `scp`.
- Ensure Git Bash runs with correct environment variables; for large rsync transfers, use an alternative if you hit permission/file line-ending issues.

---

# Final advice for submission to HNG
1. Push your repository with `deploy.sh` and `README.md`. Make sure `deploy.sh` executable bit is set (`git update-index --chmod=+x deploy.sh` before commit if on Windows).  
2. In Slack `#track-devops` and `#stage-1-devops`, run `/stage-one-devops` as instructed and post:
   - Your full name
   - GitHub repo URL `https://github.com/username/repo`
3. Test from another network/device to confirm remote accessibility.  
4. Check Thanos bot messages after each attempt (as instructed in the task).

---

If you want, I can:
- 1) add support for Let's Encrypt (Certbot) in the script, or  
- 2) produce a shorter version that only uses `docker-compose` flow, or  
- 3) adapt the script to push logs to a remote centralized logging endpoint.

Which would you like next?