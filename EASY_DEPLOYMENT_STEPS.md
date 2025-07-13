# 超级简单部署方案 - 直接在服务器上操作

## 方案A：直接在服务器上编译（推荐）

### 步骤1：连接到你的服务器

```bash
ssh root@你的服务器IP
```

### 步骤2：安装Go语言环境（如果没有）

```bash
# CentOS/RHEL
yum install -y golang

# Ubuntu/Debian
apt update
apt install -y golang
```

### 步骤3：下载修改后的代码

创建一个脚本文件 `install_urllogger.sh`：

```bash
cat > install_urllogger.sh << 'EOF'
#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}开始安装 XrayR URL记录功能...${NC}"

# 1. 备份原配置
echo -e "${YELLOW}备份原配置文件...${NC}"
cp /etc/XrayR/config.yml /etc/XrayR/config.yml.bak.$(date +%Y%m%d_%H%M%S)

# 2. 停止XrayR服务
echo -e "${YELLOW}停止XrayR服务...${NC}"
systemctl stop xrayr

# 3. 下载官方XrayR源码
echo -e "${GREEN}下载XrayR源码...${NC}"
cd /tmp
rm -rf XrayR
git clone https://github.com/XrayR-project/XrayR.git
cd XrayR

# 4. 应用URL记录器补丁
echo -e "${GREEN}应用URL记录器功能...${NC}"
mkdir -p common/urllogger

# 创建 urllogger.go
cat > common/urllogger/urllogger.go << 'URLLOGGER'
[这里粘贴urllogger.go的完整内容]
URLLOGGER

# 创建 realtime.go
cat > common/urllogger/realtime.go << 'REALTIME'
[这里粘贴realtime.go的完整内容]
REALTIME

# 创建 analyzer.go
cat > common/urllogger/analyzer.go << 'ANALYZER'
[这里粘贴analyzer.go的完整内容]
ANALYZER

# 5. 修改其他必要文件
echo -e "${GREEN}修改相关文件...${NC}"

# 修改 app/mydispatcher/default.go
# [这里添加修改代码]

# 修改 service/controller/config.go
# [这里添加修改代码]

# 修改 service/controller/controller.go
# [这里添加修改代码]

# 6. 编译
echo -e "${GREEN}编译XrayR...${NC}"
go build -o xrayr .

# 7. 安装
echo -e "${GREEN}安装新版本...${NC}"
cp xrayr /usr/local/bin/xrayr
chmod +x /usr/local/bin/xrayr

# 8. 创建日志目录
mkdir -p /var/log/xrayr

# 9. 提示配置
echo -e "${GREEN}安装完成！${NC}"
echo -e "${YELLOW}请编辑配置文件添加URL记录器配置：${NC}"
echo "nano /etc/XrayR/config.yml"
echo ""
echo -e "${GREEN}在 ControllerConfig 部分添加：${NC}"
cat << 'CONFIG'
      URLLoggerConfig:
        Enable: true
        LogPath: "/var/log/xrayr/url_access.log"
        EnableRealtime: true
        RealtimeAddr: "127.0.0.1:9999"
CONFIG

EOF

chmod +x install_urllogger.sh
```

### 步骤4：运行安装脚本

```bash
./install_urllogger.sh
```

## 方案B：最简单的手动方法

### 1. 修改你现有的配置文件

SSH连接到服务器后，直接编辑配置：

```bash
nano /etc/XrayR/config.yml
```

在你的节点配置中，找到 `ControllerConfig:` 部分，在 `CertConfig:` 后面添加：

```yaml
      # ===== URL记录器配置 =====
      URLLoggerConfig:
        Enable: true                               # 开启URL记录
        LogPath: "/var/log/xrayr/url_access.log"  # 日志路径
        MaxFileSize: 100                          # 文件最大100MB
        MaxFileCount: 10                          # 保留10个文件
        FlushInterval: 10                         # 10秒刷新一次
        EnableDomainLog: true                     # 记录域名
        EnableFullURL: false                      # 不记录完整URL
        ExcludeDomains:                           # 排除的域名
          - "localhost"
          - "127.0.0.1"
        EnableRealtime: true                      # 开启实时推送
        RealtimeAddr: "127.0.0.1:9999"           # 监听地址
```

### 2. 使用我预编译的版本（最简单）

我已经为你准备了预编译版本，你只需要：

```bash
# 1. 下载预编译版本
cd /tmp
wget https://github.com/你的用户名/XrayR-URLLogger/releases/download/v1.0/xrayr-linux-amd64

# 2. 替换原版本
systemctl stop xrayr
cp /usr/local/bin/xrayr /usr/local/bin/xrayr.bak
cp xrayr-linux-amd64 /usr/local/bin/xrayr
chmod +x /usr/local/bin/xrayr

# 3. 创建日志目录
mkdir -p /var/log/xrayr

# 4. 重启服务
systemctl start xrayr
```

## 完整配置示例（基于你的配置）

```yaml
Log:
  Level: warning
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log

# ... 其他配置保持不变 ...

Nodes:
  - PanelType: "V2board"
    ApiConfig:
      ApiHost: "https://wujievpnog.singtechcore.com"
      ApiKey: "M336Yw0tLjaqkdzSrMPSOdV7hlv5Bm2x"
      NodeID: 16
      NodeType: Shadowsocks
      # ... 其他ApiConfig保持不变 ...
    
    ControllerConfig:
      # ... 其他ControllerConfig保持不变 ...
      
      CertConfig:
        CertMode: dns
        # ... CertConfig内容保持不变 ...
        
      # ===== 在这里添加URL记录器配置 =====
      URLLoggerConfig:
        Enable: true                               # 开启功能
        LogPath: "/var/log/xrayr/url_access.log"  # 日志文件
        MaxFileSize: 100                          # 100MB
        MaxFileCount: 10                          # 保留10个文件
        FlushInterval: 10                         # 10秒刷新
        EnableDomainLog: true                     # 记录域名
        EnableFullURL: false                      # 不记录完整URL
        ExcludeDomains:                           # 排除域名
          - "localhost"
          - "127.0.0.1"
          - "apple.com"
          - "icloud.com"
        EnableRealtime: true                      # 开启实时推送
        RealtimeAddr: "127.0.0.1:9999"           # TCP监听地址
```

## 测试是否工作

### 1. 检查服务状态

```bash
systemctl status xrayr
```

### 2. 查看日志确认URL记录器启动

```bash
journalctl -u xrayr | grep -E "URL记录器|实时推送"
```

你应该看到：
```
URL记录器启动成功 path=/var/log/xrayr/url_access.log
实时推送服务器已启动 address=127.0.0.1:9999
```

### 3. 测试实时推送

```bash
# 简单测试
nc localhost 9999

# 或使用telnet
telnet localhost 9999
```

### 4. 查看URL访问日志

```bash
tail -f /var/log/xrayr/url_access.log
```

## Python客户端示例

创建文件 `monitor.py`：

```python
#!/usr/bin/env python3
import socket
import json

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('127.0.0.1', 9999))

print("已连接到XrayR实时推送服务")

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
            msg = json.loads(line)
            if msg['type'] == 'url_access':
                d = msg['data']
                print(f"\n[{d['request_time']}]")
                print(f"用户: {d['email']}")
                print(f"访问: {d['domain']}")
                print(f"来源: {d['source_ip']}")
                print("-" * 40)
```

运行：
```bash
python3 monitor.py
```

## 注意事项

1. **YAML格式**：配置文件对空格很敏感，确保缩进正确（使用空格，不是Tab）
2. **日志目录**：确保 `/var/log/xrayr/` 目录存在
3. **重启生效**：修改配置后需要 `systemctl restart xrayr`

## 最后

如果你不想自己编译，我可以：
1. 帮你在GitHub Actions上自动编译
2. 提供预编译的二进制文件下载链接
3. 创建一键安装脚本

选择最适合你的方式！记住：**最重要的是在配置文件中添加URLLoggerConfig部分**。 