#!/bin/bash

# XrayR URL Logger 一键安装脚本
# 请在服务器上直接运行此脚本

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

# 备份配置
if [ -f "/etc/XrayR/config.yml" ]; then
    echo -e "${YELLOW}备份现有配置...${NC}"
    cp /etc/XrayR/config.yml /etc/XrayR/config.yml.bak.$(date +%Y%m%d_%H%M%S)
fi

# 停止服务
echo -e "${YELLOW}停止XrayR服务...${NC}"
systemctl stop xrayr 2>/dev/null || true

# 检查Go环境
echo -e "${GREEN}检查Go环境...${NC}"
if ! command -v go &> /dev/null; then
    echo -e "${YELLOW}安装Go语言环境...${NC}"
    if [ -f /etc/redhat-release ]; then
        yum install -y golang git
    else
        apt update
        apt install -y golang git
    fi
fi

# 下载源码
echo -e "${GREEN}下载XrayR源码...${NC}"
cd /tmp
rm -rf XrayR-URLLogger
git clone https://github.com/XrayR-project/XrayR.git XrayR-URLLogger
cd XrayR-URLLogger

# 创建URL记录器模块
echo -e "${GREEN}创建URL记录器模块...${NC}"
mkdir -p common/urllogger

# 创建所有必要的文件
echo -e "${YELLOW}正在创建代码文件...${NC}"

# 从GitHub下载修改后的文件
echo -e "${GREEN}下载修改后的代码...${NC}"

# 方法1：直接下载文件（如果你已经上传到GitHub）
# wget -O common/urllogger/urllogger.go https://raw.githubusercontent.com/你的用户名/XrayR-URLLogger/main/common/urllogger/urllogger.go
# wget -O common/urllogger/realtime.go https://raw.githubusercontent.com/你的用户名/XrayR-URLLogger/main/common/urllogger/realtime.go
# wget -O common/urllogger/analyzer.go https://raw.githubusercontent.com/你的用户名/XrayR-URLLogger/main/common/urllogger/analyzer.go

# 方法2：直接创建文件（临时方案）
echo -e "${YELLOW}创建urllogger文件...${NC}"
cat > download_files.sh << 'DOWNLOAD'
#!/bin/bash

# 创建临时Python脚本来下载文件
cat > download.py << 'PYTHON'
import urllib.request
import os

# 文件URL映射（请替换为实际的URL）
files = {
    "common/urllogger/urllogger.go": "https://example.com/urllogger.go",
    "common/urllogger/realtime.go": "https://example.com/realtime.go",
    "common/urllogger/analyzer.go": "https://example.com/analyzer.go"
}

print("由于文件太大，请手动下载以下文件：")
print("")
print("1. 从你的Mac电脑复制以下文件到服务器：")
print("   - common/urllogger/urllogger.go")
print("   - common/urllogger/realtime.go") 
print("   - common/urllogger/analyzer.go")
print("")
print("2. 使用scp命令：")
print("   scp -r common/urllogger root@服务器IP:/tmp/XrayR-URLLogger/common/")
PYTHON

python3 download.py
DOWNLOAD

# 提示用户上传文件
echo -e "${RED}========================================${NC}"
echo -e "${RED}重要提示：${NC}"
echo -e "${YELLOW}由于代码文件较大，请手动上传以下文件：${NC}"
echo ""
echo -e "${GREEN}在你的Mac上执行：${NC}"
echo "cd /Volumes/SingTech/XrayR-master"
echo "scp -r common/urllogger root@$(hostname -I | awk '{print $1}'):/tmp/XrayR-URLLogger/common/"
echo "scp app/mydispatcher/default.go root@$(hostname -I | awk '{print $1}'):/tmp/XrayR-URLLogger/app/mydispatcher/"
echo "scp service/controller/config.go root@$(hostname -I | awk '{print $1}'):/tmp/XrayR-URLLogger/service/controller/"
echo "scp service/controller/controller.go root@$(hostname -I | awk '{print $1}'):/tmp/XrayR-URLLogger/service/controller/"
echo "scp panel/defaultConfig.go root@$(hostname -I | awk '{print $1}'):/tmp/XrayR-URLLogger/panel/"
echo ""
echo -e "${RED}========================================${NC}"
echo ""
read -p "文件上传完成后，按Enter继续..."

# 检查文件是否存在
if [ ! -f "common/urllogger/urllogger.go" ]; then
    echo -e "${RED}错误：文件未找到，请确保已上传所有文件${NC}"
    exit 1
fi

# 编译
echo -e "${GREEN}开始编译XrayR...${NC}"
go build -o xrayr .

if [ ! -f "xrayr" ]; then
    echo -e "${RED}编译失败！${NC}"
    exit 1
fi

# 安装
echo -e "${GREEN}安装新版本...${NC}"
cp xrayr /usr/local/bin/xrayr
chmod +x /usr/local/bin/xrayr

# 创建日志目录
mkdir -p /var/log/xrayr

# 创建示例配置
echo -e "${GREEN}创建示例配置...${NC}"
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
cat > /usr/local/bin/xrayr-monitor.py << 'MONITOR'
#!/usr/bin/env python3
import socket
import json
import sys

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
                break
            
            buffer += data
            lines = buffer.split('\n')
            buffer = lines[-1]
            
            for line in lines[:-1]:
                if line.strip():
                    try:
                        msg = json.loads(line)
                        if msg['type'] == 'url_access':
                            d = msg['data']
                            print(f"\n时间: {d['request_time']}")
                            print(f"用户: {d['email']}")
                            print(f"访问: {d['domain']}")
                            print(f"来源: {d['source_ip']}")
                            print(f"协议: {d['protocol']}")
                            print("-" * 50)
                    except:
                        pass
                        
    except KeyboardInterrupt:
        print("\n监控已停止")
    except Exception as e:
        print(f"错误: {e}")

if __name__ == "__main__":
    main()
MONITOR

chmod +x /usr/local/bin/xrayr-monitor.py

# 完成提示
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}下一步操作：${NC}"
echo ""
echo "1. 编辑配置文件："
echo "   nano /etc/XrayR/config.yml"
echo ""
echo "2. 在 ControllerConfig 部分添加URL记录器配置"
echo "   配置示例已保存在: /tmp/urllogger_config.yml"
echo ""
echo "3. 启动服务："
echo "   systemctl start xrayr"
echo ""
echo "4. 查看状态："
echo "   systemctl status xrayr"
echo ""
echo "5. 监控实时数据："
echo "   xrayr-monitor.py"
echo ""
echo "6. 查看日志文件："
echo "   tail -f /var/log/xrayr/url_access.log"
echo ""
echo -e "${GREEN}========================================${NC}" 