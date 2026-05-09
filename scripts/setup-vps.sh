#!/bin/bash
# vps-monorepo-starter — VPS setup script
# Run on a fresh Ubuntu 24.04 VPS as root
# Usage: ssh root@<vps-ip> 'bash -s' < scripts/setup-vps.sh

set -euo pipefail

echo "=== VPS Monorepo Setup ==="

# Generate secrets upfront
DB_PASSWORD=$(openssl rand -hex 24)

# ---------------------------------------------------------------------------
# Contabo (and some other hosts) have flaky IPv6 routing to Ubuntu mirrors.
# Force IPv4 to avoid apt hanging on first run.
# ---------------------------------------------------------------------------
echo "Forcing apt to use IPv4..."
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

# System updates
echo "Updating system..."
apt update && apt upgrade -y
apt install -y curl git unzip ca-certificates gnupg

# ---------------------------------------------------------------------------
# Dedicated user — app does NOT run as root
# ---------------------------------------------------------------------------
echo "Creating app user..."
id -u myapp >/dev/null 2>&1 || useradd --system --shell /bin/bash --create-home --home-dir /home/myapp myapp

# ---------------------------------------------------------------------------
# Bun — installed for the app user
# ---------------------------------------------------------------------------
echo "Installing Bun..."
sudo -u myapp bash -c 'curl -fsSL https://bun.sh/install | bash'
BUN_BIN="/home/myapp/.bun/bin/bun"

# ---------------------------------------------------------------------------
# PostgreSQL 16
# ---------------------------------------------------------------------------
echo "Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib
systemctl enable postgresql && systemctl start postgresql

sudo -u postgres psql -c "CREATE USER myapp WITH PASSWORD '${DB_PASSWORD}';" || \
  sudo -u postgres psql -c "ALTER USER myapp WITH PASSWORD '${DB_PASSWORD}';"
sudo -u postgres psql -c "CREATE DATABASE myapp_db OWNER myapp;" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Caddy — auto HTTPS
# ---------------------------------------------------------------------------
echo "Installing Caddy..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install -y caddy

# Copy Caddyfile (only if repo is already cloned at /opt/myapp)
if [ -f /opt/myapp/caddy/Caddyfile ]; then
  cp /opt/myapp/caddy/Caddyfile /etc/caddy/Caddyfile
  systemctl restart caddy
else
  echo "Skipping Caddyfile copy — clone the repo to /opt/myapp first, then run: systemctl restart caddy"
fi

# ---------------------------------------------------------------------------
# systemd services (api + web + admin)
# ---------------------------------------------------------------------------
echo "Creating systemd services..."
cat > /etc/systemd/system/myapp-api.service << EOF
[Unit]
Description=My App API
After=network.target postgresql.service

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp/api
ExecStart=${BUN_BIN} run start
Restart=always
RestartSec=5
EnvironmentFile=/opt/myapp/api/.env

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/myapp-web.service << EOF
[Unit]
Description=My App Web
After=network.target

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp/apps/web
ExecStart=${BUN_BIN} dist/server/index.mjs
Restart=always
RestartSec=5
Environment=PORT=3000
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/myapp-admin.service << EOF
[Unit]
Description=My App Admin
After=network.target

[Service]
Type=simple
User=myapp
Group=myapp
WorkingDirectory=/opt/myapp/apps/admin
ExecStart=${BUN_BIN} dist/server/index.mjs
Restart=always
RestartSec=5
Environment=PORT=3001
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable myapp-api myapp-web myapp-admin

# ---------------------------------------------------------------------------
# Daily pg_dump backups, 30-day retention
# ---------------------------------------------------------------------------
echo "Setting up backups..."
mkdir -p /var/backups/myapp
chown myapp:myapp /var/backups/myapp
(sudo -u myapp crontab -l 2>/dev/null; echo "0 2 * * * pg_dump myapp_db | gzip > /var/backups/myapp/myapp-\$(date +\%Y\%m\%d).sql.gz") | sudo -u myapp crontab -
(sudo -u myapp crontab -l 2>/dev/null; echo "0 3 * * * find /var/backups/myapp -name '*.sql.gz' -mtime +30 -delete") | sudo -u myapp crontab -

echo ""
echo "=========================================="
echo "  SETUP COMPLETE"
echo "=========================================="
echo ""
echo "  DB password (also in .env):"
echo "    ${DB_PASSWORD}"
echo ""
echo "  Next steps:"
echo "  1. Clone your repo to /opt/myapp"
echo "  2. Fill in /opt/myapp/api/.env"
echo "  3. systemctl start myapp-api"
echo "  4. Point DNS A record to this VPS IP"
echo ""
