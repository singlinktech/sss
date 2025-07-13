# XrayR URL Logger 快速使用指南

## 🚀 一键安装

```bash
# 方法1: 使用主安装脚本
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)

# 方法2: 使用快捷安装脚本
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/ONE_CLICK_INSTALL.sh)
```

## 📊 查看实时数据

### 使用内置监控工具
```bash
# 格式化显示（友好界面）
xrayr-monitor

# 纯JSON输出（适用于脚本处理）
xrayr-json-monitor

# 简单JSON输出（bash版本，无Python依赖）
xrayr-json-simple
```

### 使用Python客户端
```bash
python3 /usr/local/bin/xrayr-realtime-client.py

# 带过滤功能
python3 /usr/local/bin/xrayr-realtime-client.py --filter-domain "google.com"
python3 /usr/local/bin/xrayr-realtime-client.py --filter-user "uuid123"

# 保存到文件
python3 /usr/local/bin/xrayr-realtime-client.py --save /tmp/access.log
```

### 手动连接测试
```bash
# 使用nc连接
nc 127.0.0.1 9999

# 使用telnet连接
telnet 127.0.0.1 9999
```

### JSON格式输出
```bash
# 纯JSON输出，适用于API集成
xrayr-json-monitor

# 保存JSON到文件
xrayr-json-monitor > /tmp/url_access.json

# 结合jq处理JSON数据
xrayr-json-monitor | jq '.data.domain'

# 过滤特定域名的访问
xrayr-json-monitor | jq 'select(.data.domain | contains("google"))'
```

## 📋 数据格式

### 实时推送格式
```json
{
  "type": "url_access",
  "data": {
    "timestamp": "2025-07-14T04:30:58.464805348+08:00",
    "user_id": 23,
    "email": "a9d727cd-330b-4edd-8911-7c224df6afd5@v2board.user",
    "domain": "m.baidu.com",
    "full_url": "https://m.baidu.com:443",
    "protocol": "tls",
    "node_id": 28,
    "node_tag": "Shadowsocks_0.0.0.0_23999",
    "source_ip": "218.252.250.102",
    "user_info": "level:0,tag:Shadowsocks_0.0.0.0_23999,network:tcp",
    "request_time": "2025-07-14 04:30:58"
  }
}
```

### 文件日志格式
```json
{
  "timestamp": "2025-07-14T04:30:58.464805348+08:00",
  "user_id": 23,
  "email": "a9d727cd-330b-4edd-8911-7c224df6afd5@v2board.user",
  "domain": "m.baidu.com",
  "full_url": "https://m.baidu.com:443",
  "protocol": "tls",
  "node_id": 28,
  "node_tag": "Shadowsocks_0.0.0.0_23999",
  "source_ip": "218.252.250.102",
  "user_info": "level:0,tag:Shadowsocks_0.0.0.0_23999,network:tcp",
  "request_time": "2025-07-14 04:30:58"
}
```

## ⚙️ 配置文件

在 `/etc/XrayR/config.yml` 中添加：

```yaml
URLLoggerConfig:
  Enable: true                               # 启用URL记录器
  LogPath: "/var/log/xrayr/url_access.log"  # 日志文件路径
  MaxFileSize: 100                          # 最大文件大小(MB)
  MaxFileCount: 10                          # 最多保留的文件数
  FlushInterval: 10                         # 刷新间隔(秒)
  EnableDomainLog: true                     # 记录域名访问
  EnableFullURL: false                      # 记录完整URL
  ExcludeDomains:                           # 排除的域名
    - "localhost"
    - "127.0.0.1"
  # 实时推送配置
  EnableRealtime: true                      # 启用实时推送
  RealtimeAddr: "127.0.0.1:9999"           # 监听地址
```

## 🔧 管理命令

```bash
# 查看服务状态
systemctl status xrayr

# 启动/停止/重启服务
systemctl start xrayr
systemctl stop xrayr
systemctl restart xrayr

# 查看日志
journalctl -u xrayr -f

# 查看URL访问日志
tail -f /var/log/xrayr/url_access.log

# 使用状态管理界面
xrayr status
```

## 🔍 故障排除

### 检查服务状态
```bash
systemctl status xrayr
```

### 检查端口监听
```bash
lsof -i :9999
```

### 测试实时推送连接
```bash
telnet 127.0.0.1 9999
```

### 查看详细日志
```bash
journalctl -u xrayr | grep -E "URL记录器|实时推送|错误"
```

## 📚 完整文档

- **实时API文档**: [REALTIME_API_DOCS.md](REALTIME_API_DOCS.md)
- **项目地址**: https://github.com/singlinktech/sss

## 💡 示例用法

### 监控特定用户
```bash
python3 /usr/local/bin/xrayr-realtime-client.py \
  --filter-user "a9d727cd-330b-4edd-8911-7c224df6afd5" \
  --save /tmp/user_access.log
```

### 监控恶意域名
```bash
python3 /usr/local/bin/xrayr-realtime-client.py \
  --filter-domain "malware" \
  --save /tmp/malicious_access.log
```

### 分析访问日志
```bash
xrayr analyze -l /var/log/xrayr/url_access.log -o /tmp/analysis_report.txt
```

---

🎯 **现在您就可以实时监控用户的URL访问了！** 