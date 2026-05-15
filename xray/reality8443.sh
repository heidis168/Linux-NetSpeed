#!/bin/bash
set -e

# ==================== 配置 ====================
PORT=8443
UUID=$(cat /proc/sys/kernel/random/uuid)
SNI="www.microsoft.com"
CERTDIR="/etc/xray-cert"
mkdir -p $CERTDIR

# ==================== 安装依赖 ====================
apt update
apt install -y curl wget openssl

# ==================== 安装Xray ====================
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# ==================== 生成 Reality 密钥（修复版！） ====================
xray x25519 > $CERTDIR/key.txt
PRIVATE_KEY=$(grep "Private" $CERTDIR/key.txt | awk '{print $2}')
PUBLIC_KEY=$(grep "Public" $CERTDIR/key.txt | awk '{print $2}')

# ==================== 配置文件 ====================
cat > /usr/local/etc/xray/config.json <<EOF
{
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$SNI:443",
          "xver": 1,
          "serverNames": ["$SNI"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [""]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http","tls"]
      }
    }
  ],
  "outbounds": [{"protocol":"freedom","settings":{}}]
}
EOF

# ==================== 启动 ====================
systemctl stop ufw || true
systemctl disable ufw || true
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ==================== 输出连接信息 ====================
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=================================================="
echo "✅ 修复版 Xray VLESS-Reality 安装完成！"
echo "=================================================="
echo "IP:        $IP"
echo "端口:      $PORT"
echo "UUID:      $UUID"
echo "公钥PBK:   $PUBLIC_KEY"
echo "SNI:       $SNI"
echo "流控:      xtls-rprx-vision"
echo "=================================================="
echo "🔗 一键分享链接（直接复制导入）："
echo "vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&pbk=${PUBLIC_KEY}&sid=&type=tcp#VLESS-REALITY-8443"
echo "=================================================="