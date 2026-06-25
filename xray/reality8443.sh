#!/usr/bin/env bash
#
# Xray VLESS + Reality + Vision 一键安装脚本
# 默认端口: 8443
# 支持: 全新安装 / 重装 / 强制覆盖 / 卸载
#

set -euo pipefail

# ==================== 配置常量 ====================
DEFAULT_PORT=8443
XRAY_CONFIG="/usr/local/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
SERVICE_FILE="/etc/systemd/system/xray.service"
INSTALL_LOG="/var/log/xray-install.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==================== 工具函数 ====================
log() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$INSTALL_LOG"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$INSTALL_LOG"
}

err() {
    echo -e "${RED}[ERR ]${NC} $1" | tee -a "$INSTALL_LOG"
}

info() {
    echo -e "${CYAN}[NOTE]${NC} $1"
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        err "请使用 root 权限运行本脚本 (sudo su 或 root 登录)"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        VER=$(rpm -q --queryformat '%{VERSION}' centos-release 2>/dev/null || echo "7")
    else
        err "无法检测操作系统类型"
        exit 1
    fi
    log "检测到系统: $OS $VER"
}

install_deps() {
    log "正在安装依赖..."
    local pkgs=("curl" "openssl" "uuid-runtime" "jq")
    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y -qq curl openssl uuid-runtime jq qrencode cron iptables-persistent 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum install -y -q curl openssl util-linux jq qrencode cronie iptables-services 2>/dev/null || true
    elif command -v apk &>/dev/null; then
        apk add --no-cache curl openssl uuidgen jq qrencode 2>/dev/null || true
    elif command -v pacman &>/dev/null; then
        pacman -Sy --noconfirm curl openssl util-linux jq qrencode 2>/dev/null || true
    fi

    # 确保 jq 可用
    if ! command -v jq &>/dev/null; then
        warn "jq 未安装，尝试二进制安装..."
        curl -sL "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64" -o /usr/local/bin/jq && chmod +x /usr/local/bin/jq
    fi

    # 确保 qrencode 可用
    if ! command -v qrencode &>/dev/null; then
        warn "qrencode 未安装，二维码功能将不可用"
    fi
}

# ==================== Xray 操作 ====================
is_xray_installed() {
    [[ -f "$XRAY_BIN" ]] && [[ -f "$XRAY_CONFIG" ]]
}

stop_xray() {
    if systemctl is-active --quiet xray 2>/dev/null; then
        log "停止 xray 服务..."
        systemctl stop xray || true
    fi
    if systemctl is-enabled --quiet xray 2>/dev/null; then
        systemctl disable xray 2>/dev/null || true
    fi
}

remove_xray() {
    log "卸载现有 Xray..."
    stop_xray
    # 使用官方卸载脚本
    bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge 2>/dev/null || true
    rm -f "$XRAY_CONFIG"
    rm -rf /usr/local/etc/xray
    rm -f /usr/local/bin/xray
    rm -f /usr/local/share/xray/*.dat
    systemctl daemon-reload 2>/dev/null || true
    log "卸载完成"
}

install_xray() {
    log "正在安装/更新 Xray Core..."
    bash -c "$(curl -sL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    if [[ ! -f "$XRAY_BIN" ]]; then
        err "Xray 安装失败"
        exit 1
    fi
    log "Xray 安装成功: $($XRAY_BIN version | head -1)"
}

# ==================== 配置生成 ====================
generate_uuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        $XRAY_BIN uuid 2>/dev/null || openssl rand -hex 16 | sed 's/../&-/g; s/-$//; s/^/........-....-....-....-................/'
    fi
}

generate_keys() {
    # 单次调用 xray x25519，确保公私钥匹配
    $XRAY_BIN x25519 2>/dev/null || {
        err "xray x25519 密钥生成失败，请确认 Xray 核心已安装"
        return 1
    }
}

generate_shortid() {
    openssl rand -hex $((RANDOM % 8 + 8)) | cut -c1-16
}

get_server_ip() {
    local ip
    ip=$(curl -sL --connect-timeout 5 https://api.ipify.org 2>/dev/null || curl -sL --connect-timeout 5 https://ip.sb 2>/dev/null || echo "")
    if [[ -z "$ip" ]]; then
        ip=$(ip -4 route get 1 2>/dev/null | awk '{print $7; exit}' || hostname -I | awk '{print $1}')
    fi
    echo "$ip"
}

open_firewall() {
    local port=$1
    log "放行端口 $port ..."
    if command -v ufw &>/dev/null; then
        ufw allow "$port/tcp" &>/dev/null || true
        ufw reload &>/dev/null || true
    elif command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port="$port/tcp" &>/dev/null || true
        firewall-cmd --reload &>/dev/null || true
    elif command -v iptables &>/dev/null; then
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
        if command -v iptables-save &>/dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        fi
    fi
}

write_config() {
    local port=$1
    local uuid=$2
    local private_key=$3
    local public_key=$4
    local shortid=$5
    local domain=$6
    local sni=$7
    local sni2=${8:-www.$sni}

    mkdir -p "$(dirname "$XRAY_CONFIG")"

    cat > "$XRAY_CONFIG" <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $port,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$uuid",
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
          "dest": "$domain:443",
          "xver": 0,
          "serverNames": [
            "$sni",
            "$sni2"
          ],
          "privateKey": "$private_key",
          "publicKey": "$public_key",
          "minClientVer": "",
          "maxClientVer": "",
          "maxTimeDiff": 0,
          "shortIds": [
            "$shortid"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ],
  "routing": {
    "rules": [
      {
        "protocol": ["bittorrent"],
        "outboundTag": "block",
        "type": "field"
      }
    ]
  },
  "policy": {
    "levels": {
      "0": {
        "handshake": 2,
        "connIdle": 120
      }
    }
  }
}
EOF

    mkdir -p /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log
    chmod 755 /var/log/xray

    log "配置已写入 $XRAY_CONFIG"
}

# ==================== 输出信息 ====================
print_client_info() {
    local port=$1
    local uuid=$2
    local public_key=$3
    local shortid=$4
    local sni=$5
    local ip=$6

    local link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${shortid}&type=tcp&headerType=none#Reality-$(hostname)"

    echo ""
    echo "========================================"
    echo -e "${GREEN}     Xray VLESS Reality 配置信息${NC}"
    echo "========================================"
    echo -e "${CYAN}协议${NC}      : VLESS"
    echo -e "${CYAN}地址${NC}      : ${ip}"
    echo -e "${CYAN}端口${NC}      : ${port}"
    echo -e "${CYAN}UUID${NC}      : ${uuid}"
    echo -e "${CYAN}流控${NC}      : xtls-rprx-vision"
    echo -e "${CYAN}传输${NC}      : tcp"
    echo -e "${CYAN}安全${NC}      : reality"
    echo -e "${CYAN}SNI${NC}       : ${sni}"
    echo -e "${CYAN}PublicKey${NC} : ${public_key}"
    echo -e "${CYAN}ShortID${NC}   : ${shortid}"
    echo -e "${CYAN}指纹${NC}      : chrome"
    echo "========================================"
    echo -e "${YELLOW}分享链接:${NC}"
    echo "$link"
    echo ""

    if command -v qrencode &>/dev/null; then
        echo -e "${YELLOW}二维码:${NC}"
        echo "$link" | qrencode -t ANSIUTF8
    fi

    echo ""
    echo -e "${GREEN}v2rayN / Nekoray 导入参数:${NC}"
    echo "地址(address)  : $ip"
    echo "端口(port)     : $port"
    echo "用户ID(id)     : $uuid"
    echo "流控(flow)     : xtls-rprx-vision"
    echo "加密(encryption): none"
    echo "传输协议(network): tcp"
    echo "伪装域名(host)  : $sni"
    echo "安全(security)  : reality"
    echo "SNI            : $sni"
    echo "指纹(uTLS)     : chrome"
    echo "公钥(pbk)      : $public_key"
    echo "shortId        : $shortid"
    echo ""
}

# ==================== 安装流程 ====================
perform_install() {
    local force=${1:-false}
    local port=${2:-$DEFAULT_PORT}

    if is_xray_installed && [[ "$force" != "true" ]]; then
        warn "检测到已有 Xray 安装"
        read -rp "是否保留现有配置重装? [y/N]: " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            log "保留配置模式 (仅更新核心)..."
            install_xray
            systemctl restart xray || true
            log "Xray 核心已更新并重启"
            return
        fi
        read -rp "是否完全卸载后重装? [y/N]: " choice2
        if [[ "$choice2" =~ ^[Yy]$ ]]; then
            remove_xray
        else
            log "取消安装"
            exit 0
        fi
    elif [[ "$force" == "true" ]]; then
        log "强制覆盖模式: 先卸载现有环境..."
        remove_xray
    fi

    # 获取用户输入
    echo ""
    read -rp "请输入监听端口 [默认: $port]: " input_port
    port=${input_port:-$port}

    read -rp "请输入 Reality 目标域名(dest) [默认: 1.1.1.1]: " input_dest
    local dest=${input_dest:-1.1.1.1}

    read -rp "请输入 SNI [默认: cloudflare.com]: " input_sni
    local sni=${input_sni:-cloudflare.com}

    # 生成参数
    log "生成密钥对..."
    local keys
    keys=$($XRAY_BIN x25519 2>/dev/null || echo "")
    if [[ -z "$keys" ]]; then
        # 先安装 xray 再生成
        install_xray
        keys=$($XRAY_BIN x25519)
    fi
    local private_key=$(echo "$keys" | grep -i "private" | awk '{print $NF}')
    local public_key=$(echo "$keys" | grep -i "public" | awk '{print $NF}')

    local uuid=$(generate_uuid)
    local shortid=$(generate_shortid)
    local server_ip=$(get_server_ip)

    if [[ -z "$server_ip" ]]; then
        read -rp "无法自动获取公网IP，请手动输入服务器IP: " server_ip
    fi

    # 安装 xray (如果前面没装)
    if ! command -v xray &>/dev/null; then
        install_xray
    fi

    # 写入配置
    write_config "$port" "$uuid" "$private_key" "$public_key" "$shortid" "$dest" "$sni" "www.$sni"

    # 防火墙
    open_firewall "$port"

    # 启动
    log "启动 Xray 服务..."
    systemctl daemon-reload
    systemctl enable xray
    systemctl restart xray
    sleep 2

    if systemctl is-active --quiet xray; then
        log "Xray 服务运行正常"
    else
        err "Xray 服务启动失败，请检查日志: journalctl -u xray -n 50"
        exit 1
    fi

    # 输出
    print_client_info "$port" "$uuid" "$public_key" "$shortid" "$sni" "$server_ip"

    # 保存到文件
    local share_file="/root/xray-client-info.txt"
    cat > "$share_file" <<EOF
========================================
Xray VLESS Reality 配置信息
========================================
地址      : ${server_ip}
端口      : ${port}
UUID      : ${uuid}
流控      : xtls-rprx-vision
传输      : tcp
安全      : reality
SNI       : ${sni}
PublicKey : ${public_key}
ShortID   : ${shortid}
指纹      : chrome
========================================
分享链接:
vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${shortid}&type=tcp&headerType=none#Reality-$(hostname)
========================================
EOF
    log "配置信息已保存到: $share_file"
}

# ==================== 主入口 ====================
show_menu() {
    clear
    echo "========================================"
    echo -e "${GREEN}  Xray VLESS + Reality 一键安装脚本${NC}"
    echo "========================================"
    echo "  1. 全新安装 (智能处理已有环境)"
    echo "  2. 强制覆盖安装 (卸载现有并重装)"
    echo "  3. 仅更新 Xray 核心"
    echo "  4. 查看当前配置"
    echo "  5. 卸载 Xray"
    echo "  0. 退出"
    echo "========================================"
}

main() {
    check_root
    detect_os
    install_deps

    # 解析参数
    local force=false
    local port=$DEFAULT_PORT
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f) force=true; shift ;;
            --port|-p) port="$2"; shift 2 ;;
            --uninstall|--remove) remove_xray; exit 0 ;;
            --update) install_xray; systemctl restart xray; exit 0 ;;
            *) shift ;;
        esac
    done

    # 如果有 --force 参数直接执行
    if [[ "$force" == "true" ]]; then
        perform_install true "$port"
        exit 0
    fi

    while true; do
        show_menu
        read -rp "请选择操作 [0-5]: " choice
        case $choice in
            1)
                perform_install false "$port"
                read -rp "按回车键返回菜单..."
                ;;
            2)
                read -rp "确认强制覆盖安装? 现有配置将丢失 [y/N]: " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    perform_install true "$port"
                fi
                read -rp "按回车键返回菜单..."
                ;;
            3)
                install_xray
                systemctl restart xray || true
                log "Xray 核心已更新"
                read -rp "按回车键返回菜单..."
                ;;
            4)
                if [[ -f /root/xray-client-info.txt ]]; then
                    cat /root/xray-client-info.txt
                elif [[ -f "$XRAY_CONFIG" ]]; then
                    echo "当前配置文件内容:"
                    cat "$XRAY_CONFIG" | jq .
                else
                    warn "未找到配置文件"
                fi
                read -rp "按回车键返回菜单..."
                ;;
            5)
                read -rp "确认完全卸载 Xray? [y/N]: " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    remove_xray
                fi
                read -rp "按回车键返回菜单..."
                ;;
            0)
                echo "退出"
                exit 0
                ;;
            *)
                warn "无效选项"
                sleep 1
                ;;
        esac
    done
}

main "$@"
