#!/bin/bash
set -euo pipefail

HOST="$1"
SSH_KEY_RAW="$2"
GHCR_PAT="$3"
WORKSPACE="${GITHUB_WORKSPACE:-$(pwd)}"
DEPLOY_USER="ubuntu"
REMOTE_DIR="/opt/deploy"
ANSIBLE_DIR="ansible"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup SSH
SSH_KEY_FILE=$(mktemp)
chmod 600 "$SSH_KEY_FILE"
echo "$SSH_KEY_RAW" > "$SSH_KEY_FILE"
SSH_CONFIG=$(mktemp)
echo "StrictHostKeyChecking=no" > "$SSH_CONFIG"

log() {
  echo -e "🛠️  \033[1;34m$1\033[0m"
}

error_exit() {
  echo -e "❌ \033[0;31m$1\033[0m" >&2
  exit 1
}

trap 'rm -f "$SSH_KEY_FILE" "$SSH_CONFIG"' EXIT

log "Generating services.json from docker-compose.yml..."
npm install js-yaml --prefix "$SCRIPT_DIR" > /dev/null
node "$SCRIPT_DIR/extract-services.mjs" "$WORKSPACE/docker-compose.yml" "$WORKSPACE/services.json" || error_exit "Failed to extract services"

log "Connecting to $HOST to prepare deploy directory..."
ssh -F "$SSH_CONFIG" -i "$SSH_KEY_FILE" "$DEPLOY_USER@$HOST" \
  "sudo mkdir -p $REMOTE_DIR && sudo chown $DEPLOY_USER:$DEPLOY_USER $REMOTE_DIR" || error_exit "Failed to connect or create remote directory"

FILES="docker-compose.yml services.json"
ENV_FILES=$(find "$WORKSPACE" -maxdepth 6 -type f -name '.env.*' || true)
for file in $ENV_FILES; do
  log "Including env file: $file"
  FILES="$FILES $file"
done

log "Uploading deploy files to $HOST..."
scp -F "$SSH_CONFIG" -i "$SSH_KEY_FILE" -r $FILES "$DEPLOY_USER@$HOST:$REMOTE_DIR/" || error_exit "File upload failed"

if [ ! -d "$SCRIPT_DIR/$ANSIBLE_DIR" ]; then
  error_exit "Ansible directory not found in action"
fi

log "Uploading Ansible folder..."
scp -F "$SSH_CONFIG" -i "$SSH_KEY_FILE" -r "$SCRIPT_DIR/$ANSIBLE_DIR" "$DEPLOY_USER@$HOST:$REMOTE_DIR/" || error_exit "Failed to upload Ansible folder"

log "Persisting GHCR_PAT to /etc/environment..."
ssh -F "$SSH_CONFIG" -i "$SSH_KEY_FILE" "$DEPLOY_USER@$HOST" <<EOF
echo "GHCR_PAT=$GHCR_PAT" | sudo tee -a /etc/environment > /dev/null
EOF

log "Running remote provisioning via SSH..."
ssh -F "$SSH_CONFIG" -i "$SSH_KEY_FILE" "$DEPLOY_USER@$HOST" <<EOF
set -e
cd $REMOTE_DIR

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  rm get-docker.sh
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "❗ docker compose v2 not available"
  exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
  echo "📦 Installing Ansible..."
  sudo apt update
  sudo apt install -y ansible
fi

sudo systemctl enable docker
sudo systemctl start docker

echo "🏗️ Running Ansible playbook..."
ansible-playbook $ANSIBLE_DIR/playbook.yml -i localhost, -v || exit 1
EOF

log "✅ Provisioning complete!"
