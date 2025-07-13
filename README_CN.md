# XrayR URL访问记录器

这是一个修改版的XrayR，增加了URL访问记录和实时推送功能。

## 新增功能

### 1. URL访问记录器
- 记录所有用户访问的网站域名
- 支持日志文件自动轮转
- 可配置排除域名列表
- 异步记录，不影响代理性能

### 2. 实时推送功能
- TCP端口9999实时推送访问记录
- JSON格式，易于解析
- 支持多客户端同时连接
- 包含用户完整信息（邮箱、ID、源IP等）

### 3. 恶意网站检测
- 内置恶意域名数据库
- DGA域名检测
- 可疑TLD检测
- 自定义黑名单支持

### 4. 命令行工具
- `urlanalyzer` 命令用于分析日志
- 生成统计报告
- 检测异常访问模式

## 快速开始

### 安装

1. **方法一：使用一键脚本**
```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/ONE_CLICK_INSTALL.sh)
```

2. **方法二：手动编译**
```bash
git clone https://github.com/singlinktech/sss.git
cd sss
go build -o xrayr .
```

### 配置

在你的 `/etc/XrayR/config.yml` 中，在 `ControllerConfig` 部分添加：

```yaml
URLLoggerConfig:
  Enable: true                               # 启用URL记录器
  LogPath: "/var/log/xrayr/url_access.log"  # 日志文件路径
  MaxFileSize: 100                          # 最大文件大小(MB)
  MaxFileCount: 10                          # 最多保留的文件数
  FlushInterval: 10                         # 刷新间隔(秒)
  EnableDomainLog: true                     # 记录域名
  EnableFullURL: false                      # 是否记录完整URL
  ExcludeDomains:                           # 排除的域名
    - "localhost"
    - "127.0.0.1"
  EnableRealtime: true                      # 启用实时推送
  RealtimeAddr: "127.0.0.1:9999"           # 监听地址
```

### 使用

1. **重启服务**
```bash
systemctl restart xrayr
```

2. **查看日志**
```bash
tail -f /var/log/xrayr/url_access.log
```

3. **连接实时推送**
```bash
# 使用nc
nc localhost 9999

# 使用Python客户端
python3 examples/realtime_client.py
```

4. **分析日志**
```bash
xrayr urlanalyzer analyze -f /var/log/xrayr/url_access.log
```

## 实时推送数据格式

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

## 监控示例

### Python监控脚本
```python
import socket
import json

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('127.0.0.1', 9999))

while True:
    data = sock.recv(4096).decode('utf-8')
    for line in data.split('\n'):
        if line.strip():
            msg = json.loads(line)
            if msg['type'] == 'url_access':
                print(f"用户: {msg['data']['email']} 访问了 {msg['data']['domain']}")
```

## 文档

- [完整部署指南](DEPLOYMENT_COMPLETE_GUIDE.md)
- [简单部署步骤](SIMPLE_DEPLOYMENT_GUIDE.md)
- [URL记录器文档](docs/URL_ACCESS_LOGGER.md)
- [实时推送文档](docs/URL_ACCESS_LOGGER_REALTIME.md)

## 支持的面板

- V2board
- SSPanel
- PMPanel
- ProxyPanel
- GoV2Panel
- BunPanel

## 注意事项

1. URL记录涉及用户隐私，请遵守相关法律法规
2. 定期清理日志文件，避免磁盘空间不足
3. 实时推送端口建议只在本地监听，不要暴露到公网

## 许可证

本项目基于 XrayR 修改，遵循原项目的 GPL-3.0 许可证。

## 鸣谢

- [XrayR](https://github.com/XrayR-project/XrayR) - 原项目
- [Xray-core](https://github.com/XTLS/Xray-core) - 核心 