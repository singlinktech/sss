# XrayR URL Logger - 3分钟快速开始

## 🚀 一键安装（推荐）

```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)
```

## 📋 快速配置

### 1. 编辑配置文件

```bash
nano /etc/XrayR/config.yml
```

### 2. 修改你的面板信息

```yaml
Nodes:
  - PanelType: "V2board"      # 面板类型
    ApiConfig:
      ApiHost: "https://your-panel.com"  # 你的面板地址
      ApiKey: "your-api-key"             # 你的API密钥
      NodeID: 1                          # 你的节点ID
      NodeType: V2ray                    # 节点类型
```

### 3. 确认URL记录器配置已启用

```yaml
    ControllerConfig:
      URLLoggerConfig:
        Enable: true                               # 启用URL记录器
        LogPath: "/var/log/xrayr/url_access.log"  # 日志文件路径
        EnableRealtime: true                      # 启用实时推送
        RealtimeAddr: "127.0.0.1:9999"           # 实时推送地址
```

### 4. 启动服务

```bash
systemctl start xrayr
systemctl enable xrayr
```

## 🔍 验证运行

### 检查服务状态
```bash
systemctl status xrayr
```

### 查看日志
```bash
journalctl -u xrayr -f
```

### 监控URL访问（实时）
```bash
xrayr-monitor
```

### 查看URL访问日志
```bash
tail -f /var/log/xrayr/url_access.log
```

## 📊 数据格式

URL访问日志格式：
```json
{
  "request_time": "2024-01-01T12:00:00Z",
  "user_id": 123,
  "email": "user@example.com",
  "domain": "example.com",
  "full_url": "https://example.com/path",
  "protocol": "shadowsocks",
  "node_id": 1,
  "source_ip": "1.2.3.4",
  "user_info": {
    "device_limit": 3,
    "speed_limit": 0
  }
}
```

实时推送数据格式：
```json
{
  "type": "url_access",
  "data": {
    "request_time": "2024-01-01T12:00:00Z",
    "user_id": 123,
    "email": "user@example.com",
    "domain": "example.com",
    "source_ip": "1.2.3.4",
    "protocol": "shadowsocks"
  }
}
```

## 🛠️ 常用命令

```bash
# 查看配置帮助
xrayr-config

# 监控实时数据
xrayr-monitor

# 重启服务
systemctl restart xrayr

# 查看端口占用
netstat -tlnp | grep 9999

# 测试实时推送
nc localhost 9999
```

## 🔧 故障排除

### 服务无法启动
```bash
# 检查配置文件语法
xrayr -c /etc/XrayR/config.yml -test

# 查看详细错误日志
journalctl -u xrayr --no-pager -l
```

### 端口被占用
```bash
# 查看端口占用
lsof -i :9999

# 修改端口配置
nano /etc/XrayR/config.yml
# 修改 RealtimeAddr: "127.0.0.1:9998"
```

### 实时推送无法连接
```bash
# 确认服务运行
systemctl status xrayr

# 检查配置
grep -A5 "URLLoggerConfig" /etc/XrayR/config.yml

# 检查防火墙
iptables -L | grep 9999
```

## 📝 完整配置示例

```yaml
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
```

## 🌟 高级功能

### 恶意网站检测
系统自动检测访问的恶意网站并在日志中标记：
```json
{
  "is_malicious": true,
  "malicious_type": "phishing",
  "detection_reason": "Known phishing domain"
}
```

### 自定义排除域名
```yaml
ExcludeDomains:
  - "localhost"
  - "127.0.0.1"
  - "apple.com"
  - "icloud.com"
  - "google.com"
  - "github.com"
```

### 日志轮转配置
```yaml
MaxFileSize: 100    # 100MB
MaxFileCount: 10    # 保留10个文件
```

## 📞 技术支持

- 项目地址：https://github.com/singlinktech/sss
- 如有问题，请提交 Issue
- 功能建议欢迎 PR

---

**⚡ 安装完成后，你就可以：**
- 🔍 实时监控用户访问的网站
- 🚨 检测恶意网站访问
- 📊 分析用户行为数据
- 🔄 通过TCP推送获取实时数据

**�� 记住：修改配置文件后要重启服务！** 