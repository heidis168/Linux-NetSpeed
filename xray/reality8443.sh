#!/bin/bash
set -e

# ==================== 配置项 ====================
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

# ==================== 生成Reality密钥 ====================
cd /usr/local/bin
xray x25519 > $CERTDIR/key.txt
PRIVATE_KEY=$(sed -n '1p' $CERTDIR/key.txt | awk '{print $3}')
PUBLIC_KEY=$(sed -n '2p' $CERTDIR/key.txt | awk '{print $3}')

# ==================== 自签证书 ====================
openssl req -x509 -newkey rsa:4096 -nodes -keyout $CERTDIR/server.key -out $CERTDIR/server.crt -days 3650 -subj "/CN=localhost"

# ==================== 写入配置 ====================
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
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# ==================== 放行端口 + 启动服务 ====================
ufw allow $PORT/tcp || true
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ==================== 输出分享信息（脚本内自动打印） ====================
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "=================================================="
echo "✅  Xray VLESS-Reality 安装完成！"
echo "=================================================="
echo "🖥️  服务器IP:    $IP"
echo "🔌 端口:        $PORT"
echo "🆔 UUID:        $UUID"
echo "🔑 公钥(PBK):   $PUBLIC_KEY"
echo "🌐 SNI:         $SNI"
echo "📌 ShortID:     留空"
echo "⚡ 流控:        xtls-rprx-vision"
echo "=================================================="
echo "🔗 一键分享链接（直接复制导入）："
echo "vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SNI}&pbk=${PUBLIC_KEY}&sid=&type=tcp#VLESS-Reality-8443"
echo "=================================================="
echo ""