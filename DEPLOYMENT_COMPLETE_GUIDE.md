# XrayR URL访问记录与实时推送功能 - 完整部署指南

## 功能概述

本功能为XrayR添加了完整的URL访问记录和实时推送能力，可以：
- 记录所有用户访问的网站信息
- 实时推送访问记录到外部程序
- 分析和检测恶意网站访问
- 生成访问统计报告

## 系统架构

```
用户 → XrayR代理 → mydispatcher（流量分发）
                          ↓
                    URL记录器模块
                    ↙          ↘
              日志文件存储    TCP实时推送
                               (端口9999)
                                   ↓
                              外部接收程序
```

## 文件结构

```
XrayR-master/
├── common/urllogger/           # URL记录器核心模块
│   ├── urllogger.go           # 主记录器实现
│   ├── analyzer.go            # 恶意网站分析器
│   └── realtime.go            # TCP实时推送服务器
├── app/mydispatcher/
│   └── default.go             # 集成URL记录功能（已修改）
├── service/controller/
│   ├── config.go              # 配置结构（已修改）
│   └── controller.go          # 控制器初始化（已修改）
├── panel/
│   └── defaultConfig.go       # 默认配置（已修改）
├── cmd/
│   └── urlanalyzer.go         # URL分析命令行工具
├── examples/
│   └── realtime_client.py     # Python客户端示例
├── docs/
│   ├── URL_ACCESS_LOGGER.md          # URL记录器文档
│   └── URL_ACCESS_LOGGER_REALTIME.md # 实时推送文档
└── release/config/
    └── config_with_urllogger.yml.example # 配置示例
```

## 编译与安装

### 1. 编译XrayR

```bash
cd /path/to/XrayR-master
go build -o xrayr .
```

### 2. 安装到系统

```bash
# 复制可执行文件
sudo cp xrayr /usr/local/bin/

# 创建日志目录
sudo mkdir -p /var/log/xrayr

# 设置权限
sudo chmod +x /usr/local/bin/xrayr
```

## 配置说明

### 完整配置示例

```yaml
Log:
  Level: info                    # 日志级别
  AccessPath:                    # 访问日志路径
  ErrorPath:                     # 错误日志路径

DnsConfigPath:                   # DNS配置路径

RouteConfigPath:                 # 路由配置路径

InboundConfigPath:               # 入站配置路径

OutboundConfigPath:              # 出站配置路径

ConnetionConfig:
  Handshake: 4                   # 握手时间限制
  ConnIdle: 30                   # 连接空闲时间
  UplinkOnly: 2                  # 上行时间限制
  DownlinkOnly: 4                # 下行时间限制
  BufferSize: 64                 # 缓冲区大小

Nodes:
  - PanelType: "NewV2board"      # 面板类型
    ApiConfig:
      ApiHost: "https://your-panel.com"
      ApiKey: "your-api-key"
      NodeID: 1
      NodeType: V2ray            # 节点类型：V2ray, Trojan, Shadowsocks
      Timeout: 30
      EnableVless: false
      EnableXTLS: false
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath:              # 规则列表路径
      DisableCustomConfig: false
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriodic: 60         # 更新周期
      EnableDNS: false
      DNSType: AsIs
      DisableUploadTraffic: false
      DisableGetRule: false
      DisableIVCheck: false
      DisableSniffing: false
      EnableProxyProtocol: false
      EnableFallback: false
      FallBackConfigs:
        - SNI:
          Alpn:
          Path:
          Dest:
          ProxyProtocolVer: 0
      CertConfig:
        CertMode: none
        CertDomain:
        CertFile:
        KeyFile:
        Provider:
        Email:
        DNSEnv:
          CLOUDFLARE_EMAIL:
          CLOUDFLARE_API_KEY:
      # ===== URL记录器配置 =====
      URLLoggerConfig:
        Enable: true                            # 是否启用URL记录器
        LogPath: "/var/log/xrayr/url_access.log" # 日志文件路径
        MaxFileSize: 100                        # 最大文件大小(MB)
        MaxFileCount: 10                        # 最多保留的文件数
        FlushInterval: 10                       # 刷新间隔(秒)
        EnableDomainLog: true                   # 是否记录域名访问
        EnableFullURL: false                    # 是否记录完整URL
        ExcludeDomains:                         # 排除的域名列表
          - "example.com"
          - "localhost"
          - "127.0.0.1"
          - "googleapis.com"
          - "cloudflare.com"
        # ===== 实时推送配置 =====
        EnableRealtime: true                    # 是否启用实时推送
        RealtimeAddr: "127.0.0.1:9999"          # 实时推送监听地址
```

### 配置参数详解

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `Enable` | bool | false | 主开关，必须设置为true才能启用功能 |
| `LogPath` | string | /var/log/xrayr/url_access.log | 日志文件存储路径 |
| `MaxFileSize` | int | 100 | 单个日志文件最大大小(MB) |
| `MaxFileCount` | int | 10 | 日志文件轮转保留数量 |
| `FlushInterval` | int | 10 | 缓冲区刷新间隔(秒) |
| `EnableDomainLog` | bool | true | 是否记录域名 |
| `EnableFullURL` | bool | false | 是否记录完整URL(含路径参数) |
| `ExcludeDomains` | []string | [] | 排除的域名列表 |
| `EnableRealtime` | bool | false | 是否启用TCP实时推送 |
| `RealtimeAddr` | string | 127.0.0.1:9999 | TCP监听地址 |

## 部署步骤

### 1. 创建系统服务（systemd）

```bash
sudo cat > /etc/systemd/system/xrayr.service << EOF
[Unit]
Description=XrayR Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xrayr -c /etc/xrayr/config.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

### 2. 准备配置文件

```bash
# 创建配置目录
sudo mkdir -p /etc/xrayr

# 复制配置文件
sudo cp /path/to/your/config.yml /etc/xrayr/config.yml

# 编辑配置
sudo nano /etc/xrayr/config.yml
```

### 3. 启动服务

```bash
# 重载systemd
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start xrayr

# 设置开机自启
sudo systemctl enable xrayr

# 查看状态
sudo systemctl status xrayr
```

### 4. 检查日志

```bash
# 查看系统日志
sudo journalctl -u xrayr -f

# 查看URL访问日志
sudo tail -f /var/log/xrayr/url_access.log
```

## 实时推送使用

### 1. 测试连接

```bash
# 使用netcat测试
nc localhost 9999

# 使用telnet测试
telnet localhost 9999
```

### 2. Python客户端

```bash
# 运行示例客户端
python3 examples/realtime_client.py

# 或指定服务器地址
python3 examples/realtime_client.py 192.168.1.100 9999
```

### 3. 自定义客户端

```python
import socket
import json

def connect_and_receive():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('127.0.0.1', 9999))
    
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
                    # 处理访问记录
                    process_access_record(msg['data'])

def process_access_record(data):
    print(f"用户: {data['email']}")
    print(f"访问: {data['domain']}")
    print(f"来源IP: {data['source_ip']}")
    # 添加你的处理逻辑
```

## URL分析工具使用

### 1. 分析日志文件

```bash
# 基本分析
./xrayr urlanalyzer analyze -f /var/log/xrayr/url_access.log

# 详细分析
./xrayr urlanalyzer analyze -f /var/log/xrayr/url_access.log -v

# 生成报告
./xrayr urlanalyzer analyze -f /var/log/xrayr/url_access.log -o report.txt
```

### 2. 创建恶意域名数据库

```bash
./xrayr urlanalyzer create-malicious-db -o malicious_domains.json
```

## 数据格式说明

### 日志文件格式（JSON Lines）

```json
{"timestamp":"2024-07-14T12:00:00Z","user_id":0,"email":"user@example.com","domain":"google.com","full_url":"","protocol":"https","node_id":1,"node_tag":"node1"}
```

### 实时推送格式

```json
{
  "type": "url_access",
  "data": {
    "timestamp": "2024-07-14T12:00:00Z",
    "user_id": 0,
    "email": "user@example.com",
    "domain": "google.com",
    "full_url": "https://google.com:443",
    "protocol": "https",
    "node_id": 1,
    "node_tag": "node1",
    "source_ip": "192.168.1.100",
    "user_info": "level:0,tag:node1,network:tcp",
    "request_time": "2024-07-14 12:00:00"
  }
}
```

## 性能优化建议

### 1. 日志性能

- 使用SSD存储日志文件
- 调整`FlushInterval`平衡性能和实时性
- 定期清理旧日志文件
- 考虑使用日志轮转工具（如logrotate）

### 2. 实时推送性能

- 客户端使用连接池
- 实现断线重连机制
- 考虑使用消息队列（如Redis）作为中转

### 3. 系统资源

```bash
# 监控CPU使用
top -p $(pgrep xrayr)

# 监控内存使用
ps aux | grep xrayr

# 监控网络连接
netstat -an | grep 9999
```

## 安全建议

### 1. 访问控制

```bash
# 使用防火墙限制访问
sudo ufw allow from 192.168.1.0/24 to any port 9999

# 或使用iptables
sudo iptables -A INPUT -p tcp --dport 9999 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9999 -j DROP
```

### 2. 日志安全

```bash
# 设置日志文件权限
sudo chmod 640 /var/log/xrayr/url_access.log
sudo chown root:adm /var/log/xrayr/url_access.log
```

### 3. 数据加密

如需远程访问，建议使用SSH隧道：

```bash
# 在客户端创建SSH隧道
ssh -L 9999:localhost:9999 user@xrayr-server
```

## 故障排除

### 问题1：URL记录器未启动

检查步骤：
1. 确认配置中`Enable: true`
2. 查看XrayR日志：`journalctl -u xrayr | grep URLLogger`
3. 检查日志目录权限

### 问题2：实时推送无法连接

检查步骤：
1. 确认`EnableRealtime: true`
2. 检查端口占用：`lsof -i :9999`
3. 查看防火墙设置

### 问题3：日志文件过大

解决方案：
1. 减小`MaxFileSize`
2. 减少`MaxFileCount`
3. 使用logrotate管理

### 问题4：内存使用过高

解决方案：
1. 减小`FlushInterval`
2. 添加更多`ExcludeDomains`
3. 关闭`EnableFullURL`

## 监控与告警

### 1. 监控脚本示例

```bash
#!/bin/bash
# monitor.sh

# 检查服务状态
if ! systemctl is-active --quiet xrayr; then
    echo "XrayR服务未运行！"
    # 发送告警
fi

# 检查实时推送连接
CONNECTIONS=$(netstat -an | grep :9999 | grep ESTABLISHED | wc -l)
echo "当前实时推送连接数: $CONNECTIONS"

# 检查日志大小
LOG_SIZE=$(du -h /var/log/xrayr/url_access.log | cut -f1)
echo "当前日志大小: $LOG_SIZE"
```

### 2. 恶意网站告警

```python
# alert.py
import json
import smtplib

def check_malicious(domain):
    malicious_list = ["malware.com", "phishing.net"]
    return domain in malicious_list

def send_alert(user, domain):
    # 发送邮件告警
    msg = f"警告：用户 {user} 访问了恶意网站 {domain}"
    # 实现邮件发送逻辑
```

## 常见使用场景

### 1. 合规审计

- 记录所有用户访问记录
- 生成审计报告
- 满足监管要求

### 2. 安全监控

- 实时检测恶意网站访问
- 识别异常访问模式
- 自动触发安全响应

### 3. 流量分析

- 统计热门网站
- 分析用户行为
- 优化网络策略

### 4. 故障诊断

- 追踪连接问题
- 分析访问失败原因
- 定位性能瓶颈

## 注意事项

1. **隐私保护**：记录用户访问信息涉及隐私，请遵守相关法律法规
2. **存储空间**：日志文件会持续增长，请定期清理
3. **性能影响**：启用完整URL记录会略微影响性能
4. **安全风险**：实时推送端口请勿暴露到公网

## 版本兼容性

- XrayR版本：v0.8.0及以上
- Go版本：1.19及以上
- 支持的面板：V2board、SSPanel、PMPanel、ProxyPanel等

## 总结

本功能完整实现了URL访问记录和实时推送，具有以下优势：

1. **零侵入**：不修改核心功能，完全兼容现有系统
2. **高性能**：异步记录，缓冲写入，不影响代理性能
3. **易扩展**：标准TCP+JSON接口，支持任何语言接入
4. **功能完整**：记录、分析、推送、告警一应俱全

部署完成后，你将拥有完整的用户访问监控能力，可以实时掌握网络使用情况，及时发现和处理安全威胁。

## 技术支持

如遇到问题，请检查：
1. XrayR系统日志：`journalctl -u xrayr -n 100`
2. URL访问日志：`tail -f /var/log/xrayr/url_access.log`
3. 实时推送连接：`netstat -an | grep 9999`

祝部署顺利！ 