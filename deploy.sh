#!/bin/bash

# =============================
# HNG DevOps Stage 1 Deployment Script
# Author: Your Name (replace this)
# =============================

LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -i $LOG_FILE)
exec 2>&1

set -e

echo "🚀 Starting Deployment Process..."
echo "--------------------------------"

# ======= Collect User Input =======
read -p "Enter your GitHub repository URL: " GIT_URL
read -p "Enter your GitHub Personal Access Token: " GIT_PAT
read -p "Enter branch name (default: main): " BRANCH
BRANCH=${BRANCH:-main}

read -p "Enter remote server SSH username: " SSH_USER
read -p "Enter remote server IP address: " SSH_IP
read -p "Enter SSH private key path (e.g., ~/.ssh/mykey.pem): " SSH_KEY
read -p "Enter application internal port (e.g., 3000): " APP_PORT

echo ""
echo "Validating inputs..."

if [[ -z "$GIT_URL" || -z "$GIT_PAT" || -z "$SSH_USER" || -z "$SSH_IP" || -z "$SSH_KEY" || -z "$APP_PORT" ]]; then
  echo "❌ Missing required input. Exiting..."
  exit 1
fi

# ======= Clone or Update Repository =======
REPO_NAME=$(basename -s .git "$GIT_URL")

if [ -d "$REPO_NAME" ]; then
  echo "📦 Repository already exists locally. Pulling latest changes..."
  cd "$REPO_NAME"
  git pull origin "$BRANCH"
else
  echo "📥 Cloning repository..."
  GIT_URL_AUTH=$(echo "$GIT_URL" | sed "s#https://#https://${GIT_PAT}@#")
  git clone -b "$BRANCH" "$GIT_URL_AUTH"
  cd "$REPO_NAME"
fi

# ======= Verify Dockerfile or docker-compose.yml =======
if [[ ! -f "Dockerfile" && ! -f "docker-compose.yml" ]]; then
  echo "❌ No Dockerfile or docker-compose.yml found. Exiting..."
  exit 1
else
  echo "✅ Docker configuration found."
fi

# ======= SSH Connectivity Test =======
echo "🔗 Testing SSH connection..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_IP" "echo 'SSH connection successful! ✅'"

# ======= Prepare Remote Environment =======
echo "⚙️ Setting up remote environment..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_IP" <<EOF
  set -e
  echo "Updating packages..."
  sudo apt update -y
  sudo apt install -y docker.io docker-compose nginx

  sudo systemctl enable docker
  sudo systemctl start docker
  sudo systemctl enable nginx
  sudo systemctl start nginx

  echo "Docker version:"
  docker --version
  echo "Docker Compose version:"
  docker-compose --version

  mkdir -p ~/app
EOF

# ======= Transfer Files =======
echo "📤 Transferring project files to remote server..."
scp -i "$SSH_KEY" -r ./* "$SSH_USER@$SSH_IP:/home/$SSH_USER/app/"

# ======= Deploy with Docker Compose =======
echo "🐳 Building and starting containers..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_IP" <<EOF
  set -e
  cd ~/app
  sudo docker-compose down || true
  sudo docker-compose up -d --build
EOF

# ======= Configure Nginx =======
echo "🌐 Configuring Nginx reverse proxy..."
NGINX_CONF=$(cat <<EOT
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOT
)

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_IP" "echo '$NGINX_CONF' | sudo tee /etc/nginx/sites-available/default > /dev/null"
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_IP" "sudo nginx -t && sudo systemctl reload nginx"

# ======= Validate Deployment =======
echo "🔍 Validating deployment..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$SSH_IP" <<EOF
  echo "Checking Docker containers..."
  sudo docker ps
  echo ""
  echo "Testing local app response..."
  curl -I http://localhost:${APP_PORT} || true
EOF

echo ""
echo "✅ Deployment Complete!"
echo "Visit your app in browser: http://${SSH_IP}"
echo "Logs saved to: $LOG_FILE"