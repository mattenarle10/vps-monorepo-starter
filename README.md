# vps-monorepo-starter

Sample repo for the blog post: **I Tried a $7 VPS Instead of AWS on My Side Project. Honest Thoughts.**

A minimal Bun monorepo with two SolidJS frontend apps and one Express API, set up to deploy on a cheap VPS with Caddy and GitHub Actions.

## Structure

```
vps-monorepo-starter/
├── apps/
│   ├── web/       → app.yourdomain.com     (port 3000)
│   └── admin/     → admin.yourdomain.com   (port 3001)
├── api/           → api.yourdomain.com     (port 4000)
├── caddy/
│   └── Caddyfile  → reverse proxy + auto HTTPS config
├── scripts/
│   ├── setup-vps.sh  → run once on a fresh Ubuntu 24.04 VPS
│   └── deploy.sh     → smart path-filter deploy (called by GitHub Actions)
└── .github/
    └── workflows/deploy.yml
```

## Local dev

```bash
bun install
bun run dev:api    # port 4000
bun run dev:web    # port 3000
bun run dev:admin  # port 3001
```

## Deploying to a VPS

1. Get a VPS (Contabo, DigitalOcean, Hetzner, etc.) running Ubuntu 24.04
2. SSH in as root and run the setup script:
   ```bash
   ssh root@<your-vps-ip> 'bash -s' < scripts/setup-vps.sh
   ```
3. Clone this repo to `/opt/myapp` on the VPS
4. Fill in `/opt/myapp/api/.env` (copy from `.env.example`)
5. Copy `caddy/Caddyfile` to `/etc/caddy/Caddyfile`, update domain names
6. Point your DNS A record to the VPS IP
7. Start the API: `systemctl start myapp-api`
8. Add `SSH_PRIVATE_KEY`, `SSH_USER`, `SSH_HOST` to GitHub repo secrets

Push to `main` and GitHub Actions will handle deploys from there.

## GitHub Actions secrets needed

| Secret | Value |
|---|---|
| `SSH_PRIVATE_KEY` | Private key that has access to your VPS |
| `SSH_USER` | SSH username (usually `root`) |
| `SSH_HOST` | Your VPS IP or hostname |

---

Blog post: *coming soon*  
Author: [mattenarle.com](https://mattenarle.com)
