#!/bin/bash
# Base setup shared by the Chakra staging and replica servers. Idempotent. Usage: bootstrap.sh staging|replica
set -euo pipefail

SWAP_SIZE=4G  # swap file created on the first run
AWS_CLI_ZIP=https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip
CWAGENT_DEB=https://s3.ap-south-1.amazonaws.com/amazoncloudwatch-agent-ap-south-1/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

ROLE=${1:-}
case "$ROLE" in staging|replica) ;; *) echo "usage: $0 staging|replica" >&2; exit 2 ;; esac
export DEBIAN_FRONTEND=noninteractive
log(){ echo "$(date -u +%FT%TZ) $*"; }

log "start $ROLE"
sudo hostnamectl set-hostname "chakra-$ROLE"
grep -q "chakra-$ROLE" /etc/hosts || echo "127.0.1.1 chakra-$ROLE" | sudo tee -a /etc/hosts >/dev/null
sudo apt-get update -q
sudo apt-get -y -q -o Dpkg::Options::=--force-confold full-upgrade
pkgs=(nginx rsync git jq curl unzip ca-certificates htop ncdu tmux logrotate unattended-upgrades)
[ "$ROLE" = staging ] && pkgs+=(docker.io docker-compose-v2 postgresql-client)
[ "$ROLE" = replica ] && pkgs+=(inotify-tools s3fs)
sudo apt-get -y -q install "${pkgs[@]}"
if [ ! -f /swapfile ]; then
  sudo fallocate -l "$SWAP_SIZE" /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi
if ! command -v aws >/dev/null; then
  cd /tmp && curl -fsSLo awscliv2.zip "$AWS_CLI_ZIP" && unzip -qo awscliv2.zip && sudo ./aws/install --update && rm -rf aws awscliv2.zip
fi
if ! dpkg -s amazon-cloudwatch-agent >/dev/null 2>&1; then
  curl -fsSLo /tmp/cwa.deb "$CWAGENT_DEB" && sudo dpkg -i /tmp/cwa.deb && rm /tmp/cwa.deb
fi
[ "$ROLE" = staging ] && sudo usermod -aG docker "$USER"
sudo systemctl enable --now unattended-upgrades nginx
log "done $ROLE"; aws --version; nginx -v 2>&1; docker --version 2>/dev/null || true
