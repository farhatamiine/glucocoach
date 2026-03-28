#!/bin/bash
set -e

echo "🚀 Deploying GlucoAPI..."

# ── 1. Install Docker if not present ──────────────────────────────────────
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# ── 2. Install Nginx if not present ───────────────────────────────────────
if ! command -v nginx &> /dev/null; then
    echo "📦 Installing Nginx..."
    apt-get update && apt-get install -y nginx
fi

# ── 3. Clone or pull latest code ──────────────────────────────────────────
if [ -d "/opt/glucoapi" ]; then
    echo "📥 Pulling latest code..."
    cd /opt/glucoapi
    git pull
else
    echo "📥 Cloning repository..."
    git clone https://github.com/farhatamiine/api-cgm.git /opt/glucoapi
    cd /opt/glucoapi
fi

# ── 4. Set up .env ────────────────────────────────────────────────────────
if [ ! -f "/opt/glucoapi/.env" ]; then
    echo "⚠️  No .env file found. Copying template..."
    cp .env.production .env
    echo "❗ Edit /opt/glucoapi/.env with your real values then run this script again."
    exit 1
fi

# ── 5. Build and start containers ─────────────────────────────────────────
echo "🐳 Building and starting containers..."
docker compose down --remove-orphans
docker compose build --no-cache
docker compose up -d

# ── 6. Configure Nginx ────────────────────────────────────────────────────
echo "🔧 Configuring Nginx..."
cp nginx.conf /etc/nginx/sites-available/glucoapi
ln -sf /etc/nginx/sites-available/glucoapi /etc/nginx/sites-enabled/glucoapi
nginx -t && systemctl reload nginx

# ── 7. Health check ───────────────────────────────────────────────────────
echo "⏳ Waiting for API to start..."
sleep 5

if curl -sf http://localhost:8000/docs > /dev/null; then
    echo "✅ GlucoAPI is live!"
    echo "📍 API:  http://167.99.46.249/glucoapi/"
    echo "📍 Docs: http://167.99.46.249/glucoapi/docs"
else
    echo "❌ API did not start. Check logs:"
    echo "   docker compose logs glucoapi"
fi