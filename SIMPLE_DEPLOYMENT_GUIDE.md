# 超简单部署指南 - XrayR URL记录功能

## 准备工作

你需要：
1. 一台Linux服务器（已经在运行XrayR）
2. 能够通过SSH连接到服务器
3. 你的Mac电脑（用来编译）

## 第一步：在Mac上编译XrayR

```bash
# 1. 进入项目目录
cd /Volumes/SingTech/XrayR-master

# 2. 编译Linux版本（因为服务器是Linux）
GOOS=linux GOARCH=amd64 go build -o xrayr .

# 3. 检查是否编译成功
ls -la xrayr
```

## 第二步：上传文件到服务器

### 方法1：使用scp命令（推荐）

```bash
# 上传编译好的文件
scp xrayr root@你的服务器IP:/root/

# 上传安装脚本
scp install_with_urllogger.sh root@你的服务器IP:/root/

# 上传Python客户端示例
scp examples/realtime_client.py root@你的服务器IP:/root/
```

### 方法2：使用宝塔面板

如果你用宝塔面板，直接在文件管理器上传这些文件到 /root/ 目录

## 第三步：在服务器上安装

SSH连接到你的服务器，然后：

```bash
# 1. 进入root目录
cd /root

# 2. 给脚本执行权限
chmod +x install_with_urllogger.sh

# 3. 先停止原来的XrayR
systemctl stop xrayr

# 4. 备份原配置
cp /etc/XrayR/config.yml /etc/XrayR/config.yml.bak

# 5. 运行安装脚本
./install_with_urllogger.sh
```

## 第四步：修改配置文件

### 4.1 编辑配置

```bash
nano /etc/XrayR/config.yml
```

### 4.2 修改你的配置（在ControllerConfig部分添加）

找到你的节点配置，在 `ControllerConfig:` 下面，`CertConfig:` 之后添加：

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
          - "apple.com"                           # 可以添加更多
        # ===== 实时推送配置 =====
        EnableRealtime: true                      # 开启实时推送
        RealtimeAddr: "127.0.0.1:9999"           # 监听地址
```

### 4.3 你的完整配置应该像这样：

```yaml
Log:
  Level: warning
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json
RouteConfigPath: # /etc/XrayR/route.json
InboundConfigPath: # /etc/XrayR/custom_inbound.json
OutboundConfigPath: # /etc/XrayR/custom_outbound.json
ConnectionConfig:
  Handshake: 4
  ConnIdle: 30
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64
Nodes:
  - PanelType: "V2board"
    ApiConfig:
      ApiHost: "https://wujievpnog.singtechcore.com"
      ApiKey: "M336Yw0tLjaqkdzSrMPSOdV7hlv5Bm2x"
      NodeID: 16
      NodeType: Shadowsocks
      Timeout: 60
      EnableVless: false
      VlessFlow: "xtls-rprx-vision"
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath: # /etc/XrayR/rulelist
      DisableCustomConfig: false
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriodic: 60
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
        RedisUsername:
        RedisPassword: YOUR PASSWORD
        RedisDB: 0
        Timeout: 5
        Expiry: 60
      EnableFallback: false
      FallBackConfigs:
        - SNI:
          Alpn:
          Path:
          Dest: 80
          ProxyProtocolVer: 0
      DisableLocalREALITYConfig: false
      EnableREALITY: false
      REALITYConfigs:
        Show: true
        Dest: www.amazon.com:443
        ProxyProtocolVer: 0
        ServerNames:
          - www.amazon.com
        PrivateKey: YOUR_PRIVATE_KEY
        MinClientVer:
        MaxClientVer:
        MaxTimeDiff: 0
        ShortIds:
          - ""
          - 0123456789abcdef
      CertConfig:
        CertMode: dns
        CertDomain: "node1.test.com"
        CertFile: /etc/XrayR/cert/node1.test.com.cert
        KeyFile: /etc/XrayR/cert/node1.test.com.key
        Provider: alidns
        Email: test@me.com
        DNSEnv:
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
      # ===== URL记录器配置 =====
      URLLoggerConfig:
        Enable: true                               # 开启功能
        LogPath: "/var/log/xrayr/url_access.log"
        MaxFileSize: 100
        MaxFileCount: 10
        FlushInterval: 10
        EnableDomainLog: true
        EnableFullURL: false
        ExcludeDomains:
          - "localhost"
          - "127.0.0.1"
        EnableRealtime: true                       # 开启实时推送
        RealtimeAddr: "127.0.0.1:9999"
```

## 第五步：启动服务

```bash
# 1. 创建日志目录
mkdir -p /var/log/xrayr

# 2. 启动XrayR
systemctl start xrayr

# 3. 检查状态
systemctl status xrayr

# 4. 查看日志（确认URL记录器启动）
journalctl -u xrayr -n 50 | grep -E "URL记录器|实时推送"
```

## 第六步：测试实时推送

### 在服务器上运行Python客户端：

```bash
# 1. 安装Python3（如果没有）
yum install -y python3  # CentOS
# 或
apt install -y python3  # Ubuntu/Debian

# 2. 运行客户端
python3 /root/realtime_client.py
```

你应该看到：
```
XrayR URL访问实时推送客户端
连接到 127.0.0.1:9999
------------------------------------------------------------
[2024-07-14 12:00:00] 成功连接到服务器 127.0.0.1:9999
[服务器] XrayR URL实时推送服务
```

当有用户使用代理访问网站时，你会实时看到访问记录！

## 第七步：查看日志文件

```bash
# 查看URL访问日志
tail -f /var/log/xrayr/url_access.log

# 查看最近100条记录
tail -n 100 /var/log/xrayr/url_access.log
```

## 常用命令

```bash
# 重启XrayR
systemctl restart xrayr

# 停止XrayR
systemctl stop xrayr

# 查看XrayR状态
systemctl status xrayr

# 查看XrayR日志
journalctl -u xrayr -f

# 编辑配置文件
nano /etc/XrayR/config.yml
```

## 注意事项

1. **配置文件格式**：YAML格式对空格很敏感，确保缩进正确
2. **防火墙**：9999端口只在本地监听，不需要开放防火墙
3. **日志清理**：定期检查 /var/log/xrayr/ 目录，避免日志太大
4. **隐私保护**：URL记录涉及用户隐私，请遵守法律法规

## 故障排除

### 问题1：URL记录器没有启动

检查日志：
```bash
journalctl -u xrayr | grep -i error
```

### 问题2：实时推送连接不上

检查端口：
```bash
netstat -tlnp | grep 9999
```

### 问题3：没有记录到URL

1. 确认配置中 `Enable: true`
2. 确认有用户在使用代理
3. 检查日志目录权限

## 需要帮助？

如果遇到问题：
1. 先看XrayR日志：`journalctl -u xrayr -n 100`
2. 检查配置文件格式
3. 确认编译的版本是带URL记录功能的

## 快速测试命令

一键测试是否工作正常：
```bash
# 检查服务状态
systemctl status xrayr | grep active

# 检查URL记录器是否启动
journalctl -u xrayr | grep "URL记录器启动成功"

# 检查实时推送端口
netstat -tlnp | grep 9999

# 查看日志文件
ls -la /var/log/xrayr/
```

全部都OK就说明部署成功了！🎉 