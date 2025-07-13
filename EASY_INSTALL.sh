#!/bin/bash

# XrayR URL Logger - 简化安装脚本
# 直接下载预编译的二进制文件，无需编译

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 版本信息
VERSION="v1.0.0"
REPO_URL="https://github.com/singlinktech/sss"
DOWNLOAD_URL="https://github.com/singlinktech/sss/releases/latest/download"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}XrayR URL Logger 简化安装脚本${NC}"
echo -e "${BLUE}直接下载预编译版本，无需编译${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用root用户运行此脚本${NC}"
    exit 1
fi

# 检测系统架构
get_architecture() {
    arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        *)
            echo -e "${RED}不支持的架构: $arch${NC}"
            echo -e "${YELLOW}仅支持 x86_64 和 aarch64${NC}"
            exit 1
            ;;
    esac
}

# 检测操作系统
get_os() {
    if [ -f /etc/redhat-release ]; then
        echo "centos"
    elif grep -qi "debian" /etc/os-release; then
        echo "debian"
    elif grep -qi "ubuntu" /etc/os-release; then
        echo "ubuntu"
    else
        echo "linux"
    fi
}

ARCH=$(get_architecture)
OS=$(get_os)

echo -e "${GREEN}检测到系统: $OS ${ARCH}${NC}"

# 安装必要工具
echo -e "${GREEN}安装必要工具...${NC}"
if [ "$OS" = "centos" ]; then
    yum update -y
    yum install -y wget curl systemd
else
    apt-get update -y
    apt-get install -y wget curl systemd
fi

# 备份现有配置
if [ -f "/etc/XrayR/config.yml" ]; then
    echo -e "${YELLOW}备份现有配置...${NC}"
    cp /etc/XrayR/config.yml /etc/XrayR/config.yml.bak.$(date +%Y%m%d_%H%M%S)
fi

# 停止现有服务
echo -e "${YELLOW}停止现有服务...${NC}"
systemctl stop xrayr 2>/dev/null || true
systemctl stop XrayR 2>/dev/null || true

# 下载预编译的二进制文件
echo -e "${GREEN}下载预编译的二进制文件...${NC}"
BINARY_NAME="xrayr-linux-${ARCH}"
DOWNLOAD_FILE="/tmp/${BINARY_NAME}"

# 尝试从GitHub releases下载
echo -e "${GREEN}从 GitHub releases 下载: ${BINARY_NAME}${NC}"
if ! wget -O "$DOWNLOAD_FILE" "${DOWNLOAD_URL}/${BINARY_NAME}"; then
    echo -e "${RED}下载失败！${NC}"
    echo -e "${YELLOW}可能的原因：${NC}"
    echo "1. 网络连接问题"
    echo "2. GitHub访问受限"
    echo "3. 预编译版本尚未发布"
    echo ""
    echo -e "${YELLOW}请访问 ${REPO_URL}/releases 查看可用版本${NC}"
    exit 1
fi

# 检查下载的文件
if [ ! -f "$DOWNLOAD_FILE" ] || [ ! -s "$DOWNLOAD_FILE" ]; then
    echo -e "${RED}下载的文件无效或为空${NC}"
    exit 1
fi

# 创建目录
echo -e "${GREEN}创建必要目录...${NC}"
mkdir -p /usr/local/bin
mkdir -p /etc/XrayR
mkdir -p /var/log/xrayr

# 安装二进制文件
echo -e "${GREEN}安装二进制文件...${NC}"
cp "$DOWNLOAD_FILE" /usr/local/bin/xrayr
chmod +x /usr/local/bin/xrayr

# 创建软链接
ln -sf /usr/local/bin/xrayr /usr/bin/xrayr
ln -sf /usr/local/bin/xrayr /usr/bin/XrayR

# 验证安装
echo -e "${GREEN}验证安装...${NC}"
if ! /usr/local/bin/xrayr version &>/dev/null; then
    echo -e "${YELLOW}注意: 无法验证版本，但程序已安装${NC}"
fi

# 下载配置文件示例
echo -e "${GREEN}下载配置文件示例...${NC}"
wget -O /tmp/config.yml.example "https://raw.githubusercontent.com/singlinktech/sss/main/release/config/config.yml.example" || {
    echo -e "${YELLOW}配置文件示例下载失败，创建基础配置...${NC}"
    
    # 创建基础配置文件
    cat > /tmp/config.yml.example << 'EOF'
Log:
  Level: warning
  AccessPath: 
  ErrorPath: 
DnsConfigPath: 
InboundConfigPath: 
OutboundConfigPath: 
RouteConfigPath: 
ConnectionConfig:
  Handshake: 4
  ConnIdle: 30
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64
Nodes:
  - PanelType: "V2board"
    ApiConfig:
      ApiHost: "https://your-panel.com"
      ApiKey: "your-api-key"
      NodeID: 1
      NodeType: V2ray
      Timeout: 30
      EnableVless: false
      EnableXTLS: false
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath: 
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriod: 60
      EnableDNS: false
      DNSType: AsIs
      EnableProxyProtocol: false
      AutoSpeedLimitConfig:
        Limit: 0
        WarnTimes: 0
        LimitSpeed: 0
        LimitDuration: 0
      GlobalDeviceLimitConfig:
        Enable: false
        RedisNetwork: tcp
        RedisAddr: 127.0.0.1:6379
        RedisPassword: PASSWORD
        RedisDB: 0
        Timeout: 5
        Expiry: 60
      # URL记录器配置
      URLLoggerConfig:
        Enable: true
        LogPath: "/var/log/xrayr/url_access.log"
        MaxFileSize: 100
        MaxFileCount: 10
        FlushInterval: 10
        EnableDomainLog: true
        EnableFullURL: false
        ExcludeDomains:
          - "localhost"
          - "127.0.0.1"
          - "apple.com"
          - "icloud.com"
        EnableRealtime: true
        RealtimeAddr: "127.0.0.1:9999"
EOF
}

# 复制配置文件（如果不存在）
if [ ! -f "/etc/XrayR/config.yml" ]; then
    cp /tmp/config.yml.example /etc/XrayR/config.yml
    echo -e "${GREEN}已创建配置文件: /etc/XrayR/config.yml${NC}"
fi

# 下载必要的geo文件
echo -e "${GREEN}下载地理位置数据文件...${NC}"
wget -O /etc/XrayR/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" || {
    echo -e "${YELLOW}geoip.dat 下载失败，服务仍可正常运行${NC}"
}

wget -O /etc/XrayR/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" || {
    echo -e "${YELLOW}geosite.dat 下载失败，服务仍可正常运行${NC}"
}

# 创建systemd服务
echo -e "${GREEN}创建系统服务...${NC}"
cat > /etc/systemd/system/xrayr.service << 'EOF'
[Unit]
Description=XrayR Service with URL Logger
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xrayr -c /etc/XrayR/config.yml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# 兼容旧服务名
ln -sf /etc/systemd/system/xrayr.service /etc/systemd/system/XrayR.service

# 重载systemd
systemctl daemon-reload
systemctl enable xrayr

# 创建监控脚本
echo -e "${GREEN}创建监控工具...${NC}"
cat > /usr/local/bin/xrayr-monitor << 'MONITOR'
#!/usr/bin/env python3
import socket
import json
import sys
import time

def main():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('127.0.0.1', 9999))
        print("已连接到XrayR URL实时推送服务")
        print("-" * 50)
        
        buffer = ""
        while True:
            try:
                data = sock.recv(4096).decode('utf-8')
                if not data:
                    print("\n连接断开，5秒后重连...")
                    time.sleep(5)
                    main()
                    
                buffer += data
                lines = buffer.split('\n')
                buffer = lines[-1]
                
                for line in lines[:-1]:
                    if line.strip():
                        try:
                            msg = json.loads(line)
                            if msg.get('type') == 'url_access':
                                d = msg.get('data', {})
                                print(f"时间: {d.get('request_time', 'N/A')}")
                                print(f"用户: {d.get('email', 'N/A')}")
                                print(f"域名: {d.get('domain', 'N/A')}")
                                print(f"来源: {d.get('source_ip', 'N/A')}")
                                print(f"协议: {d.get('protocol', 'N/A')}")
                                print("-" * 50)
                        except json.JSONDecodeError:
                            pass
            except socket.timeout:
                pass
                
    except KeyboardInterrupt:
        print("\n监控已停止")
        sys.exit(0)
    except ConnectionRefusedError:
        print("错误：无法连接到实时推送服务")
        print("请检查：")
        print("1. XrayR是否正在运行")
        print("2. URLLoggerConfig中EnableRealtime是否为true")
        print("3. 端口9999是否被占用")
        sys.exit(1)
    except Exception as e:
        print(f"连接错误: {e}")
        time.sleep(5)
        main()

if __name__ == "__main__":
    main()
MONITOR

chmod +x /usr/local/bin/xrayr-monitor

# 创建快速配置脚本
echo -e "${GREEN}创建快速配置脚本...${NC}"
cat > /usr/local/bin/xrayr-config << 'CONFIG'
#!/bin/bash
echo "XrayR URL Logger 快速配置"
echo "=================================="
echo ""
echo "当前配置文件位置: /etc/XrayR/config.yml"
echo ""
echo "请确保在 ControllerConfig 部分包含以下配置："
echo ""
echo "URLLoggerConfig:"
echo "  Enable: true                               # 启用URL记录器"
echo "  LogPath: \"/var/log/xrayr/url_access.log\"  # 日志文件路径"
echo "  MaxFileSize: 100                          # 最大文件大小(MB)"
echo "  MaxFileCount: 10                          # 最多保留文件数"
echo "  FlushInterval: 10                         # 刷新间隔(秒)"
echo "  EnableDomainLog: true                     # 记录域名访问"
echo "  EnableFullURL: false                      # 记录完整URL"
echo "  ExcludeDomains:                           # 排除域名"
echo "    - \"localhost\""
echo "    - \"127.0.0.1\""
echo "    - \"apple.com\""
echo "    - \"icloud.com\""
echo "  EnableRealtime: true                      # 启用实时推送"
echo "  RealtimeAddr: \"127.0.0.1:9999\"           # 实时推送地址"
echo ""
echo "配置完成后运行: systemctl restart xrayr"
echo ""
CONFIG

chmod +x /usr/local/bin/xrayr-config

# 清理临时文件
rm -f "$DOWNLOAD_FILE" /tmp/config.yml.example

# 完成提示
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}          安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}下一步操作：${NC}"
echo ""
echo -e "${YELLOW}1. 配置你的面板信息：${NC}"
echo "   nano /etc/XrayR/config.yml"
echo ""
echo -e "${YELLOW}2. 修改以下配置：${NC}"
echo "   - ApiHost: 你的面板地址"
echo "   - ApiKey: 你的API密钥"
echo "   - NodeID: 你的节点ID"
echo ""
echo -e "${YELLOW}3. 启动服务：${NC}"
echo "   systemctl start xrayr"
echo ""
echo -e "${YELLOW}4. 查看服务状态：${NC}"
echo "   systemctl status xrayr"
echo ""
echo -e "${YELLOW}5. 查看日志：${NC}"
echo "   journalctl -u xrayr -f"
echo ""
echo -e "${YELLOW}6. 监控URL访问：${NC}"
echo "   xrayr-monitor"
echo ""
echo -e "${YELLOW}7. 查看配置帮助：${NC}"
echo "   xrayr-config"
echo ""
echo -e "${YELLOW}8. 查看URL访问日志：${NC}"
echo "   tail -f /var/log/xrayr/url_access.log"
echo ""
echo -e "${GREEN}项目地址：${REPO_URL}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}URL记录器已启用，将记录用户访问的网站信息${NC}"
echo -e "${BLUE}实时推送服务运行在端口9999${NC}"
echo -e "${BLUE}恶意网站检测功能已集成${NC}"
echo "" 