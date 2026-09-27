#!/usr/bin/env bash
set -euo pipefail

# Порт SSH по умолчанию (можно передать другой первым аргументом при запуске)
SSH_PORT="${1:-19842}"

# Отключаем интерактивные диалоговые окна apt/needrestart в Ubuntu 24.04
export DEBIAN_FRONTEND=noninteractive

echo "==> [1/5] Обновление системы и установка базовых утилит..."
apt-get update -y
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-get install -y curl nano openssl gpg ufw ca-certificates

echo "==> [2/5] Смена порта SSH на ${SSH_PORT}..."
mkdir -p /etc/ssh/sshd_config.d
echo "Port ${SSH_PORT}" > /etc/ssh/sshd_config.d/port.conf

mkdir -p /etc/systemd/system/ssh.socket.d
cat <<EOF > /etc/systemd/system/ssh.socket.d/listen.conf
[Socket]
ListenStream=
ListenStream=0.0.0.0:${SSH_PORT}
ListenStream=[::]:${SSH_PORT}
EOF

echo "==> [3/5] Добавление правил в файрвол UFW..."
ufw allow "${SSH_PORT}/tcp"
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp

systemctl daemon-reload
systemctl stop ssh.service || true
systemctl restart ssh.socket || true
systemctl restart ssh.service

echo "==> [4/5] Включение TCP BBR и увеличение UDP-буферов для Hysteria 2 / VLESS..."
cat <<EOF > /etc/sysctl.d/99-vpn-network.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=16777216
net.core.wmem_max=16777216
EOF
sysctl --system

echo "==> [5/5] Установка официального Docker и Docker Compose..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
else
    echo "Docker уже установлен, пропускаем."
fi

echo "============================================================"
echo "Готово! Порт SSH изменен на ${SSH_PORT}, BBR и Docker активны."
ss -tulpn | grep "${SSH_PORT}" || true
echo "============================================================"