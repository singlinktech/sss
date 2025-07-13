#!/bin/bash

# XrayR URL Logger 一键安装脚本
# 直接从GitHub下载完整项目，无需手动操作

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}XrayR URL记录器一键安装脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用root用户运行此脚本${NC}"
    exit 1
fi

# 检测系统
if [ -f /etc/redhat-release ]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"  
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
fi

# 备份配置
if [ -f "/etc/XrayR/config.yml" ]; then
    echo -e "${YELLOW}备份现有配置...${NC}"
    cp /etc/XrayR/config.yml /etc/XrayR/config.yml.bak.$(date +%Y%m%d_%H%M%S)
fi

# 停止服务
echo -e "${YELLOW}停止XrayR服务...${NC}"
systemctl stop xrayr 2>/dev/null || true
systemctl stop XrayR 2>/dev/null || true

# 安装依赖
echo -e "${GREEN}安装依赖...${NC}"
if [ "$release" == "centos" ]; then
    yum install -y git golang wget curl
else
    apt update
    apt install -y git golang wget curl
fi

# 检查Go版本
GO_VERSION=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
GO_MAJOR=$(echo "$GO_VERSION" | cut -d. -f1)
GO_MINOR=$(echo "$GO_VERSION" | cut -d. -f2)

# 需要Go 1.20或更高版本
if [ -z "$GO_VERSION" ] || [ "$GO_MAJOR" -lt 1 ] || ([ "$GO_MAJOR" -eq 1 ] && [ "$GO_MINOR" -lt 20 ]); then
    echo -e "${YELLOW}Go版本过低或未安装，正在安装Go 1.21...${NC}"
    
    # 删除旧版本Go
    rm -rf /usr/local/go
    
    # 下载并安装Go 1.21
    case "$(uname -m)" in
        x86_64)
            GO_ARCH="amd64"
            ;;
        aarch64)
            GO_ARCH="arm64"
            ;;
        *)
            GO_ARCH="amd64"
            ;;
    esac
    
    wget -O go.tar.gz "https://go.dev/dl/go1.21.0.linux-${GO_ARCH}.tar.gz" || \
    wget -O go.tar.gz "https://golang.google.cn/dl/go1.21.0.linux-${GO_ARCH}.tar.gz"
    
    tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz
    
    # 设置环境变量
    export PATH=/usr/local/go/bin:$PATH
    echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
    echo 'export PATH=/usr/local/go/bin:$PATH' >> /etc/profile
    
    # 验证安装
    /usr/local/go/bin/go version
else
    echo -e "${GREEN}Go版本检查通过: $GO_VERSION${NC}"
fi

# 下载项目
echo -e "${GREEN}下载XrayR-URLLogger项目...${NC}"
cd /tmp
rm -rf XrayR-URLLogger
git clone https://github.com/singlinktech/sss.git XrayR-URLLogger

if [ ! -d "XrayR-URLLogger" ]; then
    echo -e "${RED}下载失败！请检查网络连接${NC}"
    exit 1
fi

cd XrayR-URLLogger

# 检查关键文件是否存在
echo -e "${GREEN}检查项目文件...${NC}"
if [ ! -f "common/urllogger/urllogger.go" ]; then
    echo -e "${RED}错误：项目文件不完整！${NC}"
    exit 1
fi

# 编译
echo -e "${GREEN}开始编译XrayR...${NC}"
export CGO_ENABLED=0
export GOPROXY=https://goproxy.cn,direct

# 下载依赖
go mod download

# 编译
go build -o xrayr -trimpath -ldflags "-s -w -buildid=" ./main.go

if [ ! -f "xrayr" ]; then
    echo -e "${RED}编译失败！${NC}"
    echo -e "${YELLOW}尝试查看错误信息...${NC}"
    go build -o xrayr ./main.go
    exit 1
fi

# 安装
echo -e "${GREEN}安装XrayR...${NC}"

# 创建目录
mkdir -p /usr/local/bin
mkdir -p /etc/XrayR
mkdir -p /var/log/xrayr

# 复制二进制文件
cp xrayr /usr/local/bin/xrayr
chmod +x /usr/local/bin/xrayr

# 创建软链接
ln -sf /usr/local/bin/xrayr /usr/bin/xrayr
ln -sf /usr/local/bin/xrayr /usr/bin/XrayR

# 复制配置文件（如果不存在）
if [ ! -f "/etc/XrayR/config.yml" ]; then
    cp release/config/config.yml.example /etc/XrayR/config.yml
fi

# 复制geo文件
cp release/config/*.dat /etc/XrayR/ 2>/dev/null || true

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

[Install]
WantedBy=multi-user.target
EOF

# 兼容旧服务名
ln -sf /etc/systemd/system/xrayr.service /etc/systemd/system/XrayR.service

# 重载systemd
systemctl daemon-reload
systemctl enable xrayr

# 创建示例配置
echo -e "${GREEN}创建URL记录器配置示例...${NC}"
cat > /tmp/urllogger_config.yml << 'CONFIG'
# ===== URL记录器配置 =====
# 请将以下配置添加到你的 /etc/XrayR/config.yml 中的 ControllerConfig 部分
URLLoggerConfig:
  Enable: true                               # 是否启用URL记录器
  LogPath: "/var/log/xrayr/url_access.log"  # 日志文件路径
  MaxFileSize: 100                          # 最大文件大小(MB)
  MaxFileCount: 10                          # 最多保留的文件数
  FlushInterval: 10                         # 刷新间隔(秒)
  EnableDomainLog: true                     # 是否记录域名访问
  EnableFullURL: false                      # 是否记录完整URL
  ExcludeDomains:                           # 排除的域名列表
    - "localhost"
    - "127.0.0.1"
    - "apple.com"
    - "icloud.com"
  # ===== 实时推送配置 =====
  EnableRealtime: true                      # 是否启用实时推送
  RealtimeAddr: "127.0.0.1:9999"           # 实时推送监听地址
CONFIG

# 创建Python监控脚本
echo -e "${GREEN}创建监控脚本...${NC}"
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
            data = sock.recv(4096).decode('utf-8')
            if not data:
                print("\n服务器断开连接，5秒后重连...")
                time.sleep(5)
                main()  # 重新连接
                
            buffer += data
            lines = buffer.split('\n')
            buffer = lines[-1]
            
            for line in lines[:-1]:
                if line.strip():
                    try:
                        msg = json.loads(line)
                        if msg['type'] == 'url_access':
                            d = msg['data']
                            print(f"\n时间: {d.get('request_time', 'N/A')}")
                            print(f"用户: {d.get('email', 'N/A')}")
                            print(f"访问: {d.get('domain', 'N/A')}")
                            print(f"来源: {d.get('source_ip', 'N/A')}")
                            print(f"协议: {d.get('protocol', 'N/A')}")
                            print("-" * 50)
                    except json.JSONDecodeError:
                        pass
                        
    except KeyboardInterrupt:
        print("\n监控已停止")
    except ConnectionRefusedError:
        print("错误：无法连接到实时推送服务器")
        print("请确保：")
        print("1. XrayR正在运行")
        print("2. URLLoggerConfig中EnableRealtime设置为true")
        print("3. 端口9999没有被占用")
    except Exception as e:
        print(f"错误: {e}")

if __name__ == "__main__":
    main()
MONITOR

chmod +x /usr/local/bin/xrayr-monitor

# 复制Python客户端示例
if [ -f "examples/realtime_client.py" ]; then
    cp examples/realtime_client.py /usr/local/bin/xrayr-realtime-client.py
    chmod +x /usr/local/bin/xrayr-realtime-client.py
fi

# 完成提示
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}重要：你需要修改配置文件来启用URL记录功能！${NC}"
echo ""
echo "1. 编辑配置文件："
echo "   nano /etc/XrayR/config.yml"
echo ""
echo "2. 在你的节点配置的 ControllerConfig 部分添加："
echo "   cat /tmp/urllogger_config.yml"
echo ""
echo "3. 启动服务："
echo "   systemctl start xrayr"
echo ""
echo "4. 查看服务状态："
echo "   systemctl status xrayr"
echo ""
echo "5. 查看日志确认URL记录器启动："
echo "   journalctl -u xrayr | grep -E 'URL记录器|实时推送'"
echo ""
echo "6. 监控实时数据："
echo "   xrayr-monitor"
echo ""
echo "7. 查看URL访问日志："
echo "   tail -f /var/log/xrayr/url_access.log"
echo ""
echo -e "${GREEN}项目地址：https://github.com/singlinktech/sss${NC}"
echo -e "${GREEN}========================================${NC}"

# 清理
cd /
rm -rf /tmp/XrayR-URLLogger 