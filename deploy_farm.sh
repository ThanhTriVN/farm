#!/bin/bash
set -e

### ===== CONFIG =====
TRAFF_TOKEN="gHaJiLa3Ko/fKkedOFWw1iaHpojlxJ6HDltmG4ALEQQ="
PACKET_CID="dGhhbmh0cmk6MTg1NDc2Nw=="
SCRIPT_PATH="/root/deploy_farm.sh"
CRON_FILE="/etc/cron.d/farm_autostart"
### ==================

echo "===== UPDATE SYSTEM ====="
apt update -y
apt install -y ca-certificates curl gnupg lsb-release

echo "===== INSTALL DOCKER ====="
if ! command -v docker &> /dev/null; then
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

  apt update -y
  apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

systemctl enable docker
systemctl start docker

echo "===== CLEAN OLD CONTAINERS ====="
docker stop traffmonetizer psclient watchtower 2>/dev/null || true
docker rm traffmonetizer psclient watchtower 2>/dev/null || true
docker rmi traffmonetizer/cli_v2 packetstream/psclient containrrr/watchtower 2>/dev/null || true

echo "===== RUN TRAFFMONETIZER (OFFICIAL) ====="
docker run -d \
  --name traffmonetizer \
  --restart=always \
  traffmonetizer/cli_v2 start accept \
  --token "$TRAFF_TOKEN"

echo "===== RUN PACKETSTREAM (OFFICIAL) ====="
docker run -d \
  --restart=always \
  -e CID="$PACKET_CID" \
  --name psclient \
  packetstream/psclient:latest

docker run -d \
  --restart=always \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --cleanup \
  --include-stopped \
  --include-restarting \
  --revive-stopped \
  --interval 60 psclient

echo "===== SET AUTO RUN ON REBOOT ====="
if [ ! -f "$CRON_FILE" ]; then
  echo "@reboot root bash $SCRIPT_PATH >> /var/log/farm_autostart.log 2>&1" > "$CRON_FILE"
  chmod 644 "$CRON_FILE"
  echo "Auto-run on reboot ENABLED"
else
  echo "Auto-run on reboot already exists"
fi

echo "===== DONE ====="
docker ps
