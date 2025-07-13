# 🚀 XrayR 实时数据API - 一键安装完成！

## 🎉 恭喜！您现在拥有最强大的实时数据API系统

您只需要一条命令就能获得完整的XrayR实时数据API功能：

```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/ONE_CLICK_INSTALL.sh)
```

## ✨ 已经为您自动配置的功能

### 🔥 实时数据推送 (自动启用)
- **TCP端口 9999** - 实时推送所有访问数据
- **零文件存储** - 不占用硬盘空间
- **毫秒级延迟** - 最快的数据传输

### 🌐 多协议API支持 (可选启用)
- **HTTP API 端口 8080** - 标准REST接口
- **WebSocket 端口 8081** - 实时双向通信
- **完整客户端示例** - 多种编程语言

### 🔧 管理工具 (已安装)
- **xrayr-manage** - 交互式管理面板
- **xrayr-test** - 快速连接测试
- **防火墙自动配置** - 端口自动开放

## 📊 默认配置文件 (已优化)

安装脚本已经为您创建了优化的配置文件 `/etc/XrayR/config.yml`：

```yaml
# 🚀 URL记录器配置 - 实时数据API核心功能
URLLoggerConfig:
  Enable: true                          # ✅ 启用URL记录器
  LogPath: ""                           # 🔥 留空 = 纯实时模式，不保存文件
  MaxFileSize: 0                        # 🔥 0 = 不保存文件，节省空间
  MaxFileCount: 0                       # 🔥 0 = 不保存文件
  FlushInterval: 1                      # 1秒立即推送，最佳实时性
  EnableDomainLog: true                 # 启用域名记录
  EnableFullURL: true                   # 🚀 启用完整URL记录
  
  # 🌐 实时推送配置 (核心功能)
  EnableRealtime: true                  # 🔥 启用实时推送
  RealtimeAddr: "0.0.0.0:9999"         # 🔥 监听所有网络接口，端口9999
  
  # 🔧 域名过滤配置 (已优化)
  ExcludeDomains:                       # 排除不需要记录的域名
    - "localhost"
    - "127.0.0.1"
    - "apple.com"                       # 排除苹果系统请求
    - "icloud.com"
    - "microsoft.com"                   # 排除微软系统请求
    - "windows.com"
    - "ubuntu.com"                      # 排除系统更新请求
    - "debian.org"
    - "google.com/generate_204"         # 排除网络检测请求
    - "gstatic.com"
    - "googleapis.com"
```

## 🚀 立即使用 - 3个步骤

### 步骤1: 修改面板配置
```bash
nano /etc/XrayR/config.yml
```

需要修改的字段：
- `ApiHost`: 您的面板地址 (如: https://wujievpn.singtechcore.com)
- `ApiKey`: 您的API密钥
- `NodeID`: 您的节点ID (如: 28)
- `NodeType`: 节点类型 (如: Shadowsocks)

### 步骤2: 重启服务
```bash
systemctl restart xrayr
```

### 步骤3: 测试连接
```bash
xrayr-test
```

## 📡 实时数据获取示例

### 方式1: 直接TCP连接 (最简单)
```python
import socket
import json

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('您的服务器IP', 9999))

buffer = ""
while True:
    data = sock.recv(4096).decode('utf-8')
    buffer += data
    lines = buffer.split('\n')
    buffer = lines[-1]
    
    for line in lines[:-1]:
        if line.strip():
            try:
                message = json.loads(line.strip())
                if message.get('type') == 'url_access':
                    user_data = message['data']
                    print(f"用户 {user_data['user_id']} 访问了 {user_data['domain']}")
                    # 🔥 在这里处理您的数据
            except json.JSONDecodeError:
                pass
```

### 方式2: 启用HTTP API代理
```bash
# 启用HTTP API服务
/opt/xrayr-api/manage.sh enable

# 测试API
curl "http://您的服务器IP:8080/api/records?limit=10"
curl "http://您的服务器IP:8080/api/stats"
```

### 方式3: 测试WebSocket连接
```bash
# WebSocket地址
ws://您的服务器IP:8081/ws
```

## 🎯 数据格式 (已统一)

您会收到以下格式的JSON数据：

```json
{
  "type": "url_access",
  "data": {
    "timestamp": "2025-01-14T12:30:45.123456789+08:00",
    "user_id": 123,
    "email": "user@example.com",
    "domain": "www.google.com",
    "full_url": "https://www.google.com:443",
    "protocol": "tls",
    "node_id": 28,
    "node_tag": "Shadowsocks_0.0.0.0_23999",
    "source_ip": "192.168.1.100",
    "user_info": "level:1,tag:vip,network:tcp",
    "request_time": "2025-01-14 12:30:45"
  }
}
```

## 🔧 管理命令 (已创建)

### 交互式管理面板
```bash
xrayr-manage
```

### 快速命令
```bash
# 查看服务状态
systemctl status xrayr

# 查看实时日志
journalctl -u xrayr -f

# 测试连接
xrayr-test

# 编辑配置
nano /etc/XrayR/config.yml

# 重启服务
systemctl restart xrayr

# API代理管理
/opt/xrayr-api/manage.sh
```

## 💡 使用场景示例

### 1. 用户行为监控
```python
def monitor_user_behavior(data):
    user_id = data['user_id']
    domain = data['domain']
    
    # 记录到数据库
    save_to_database(user_id, domain, data['timestamp'])
    
    # 检查异常行为
    if is_suspicious_domain(domain):
        send_alert(f"用户 {user_id} 访问可疑域名: {domain}")
```

### 2. 实时统计分析
```python
def analyze_traffic(data):
    # 统计热门域名
    update_domain_stats(data['domain'])
    
    # 统计用户活跃度
    update_user_activity(data['user_id'])
    
    # 节点负载分析
    update_node_stats(data['node_id'])
```

### 3. 安全监控
```python
def security_monitor(data):
    # 检测恶意域名
    if data['domain'] in malicious_domains:
        block_user(data['user_id'])
    
    # 监控大流量用户
    if get_user_traffic(data['user_id']) > threshold:
        send_warning(data['user_id'])
```

## 🎉 完成！您现在拥有：

✅ **零配置实时数据推送** - 默认开启  
✅ **完整的API工具包** - 多种对接方式  
✅ **优化的配置文件** - 最佳性能设置  
✅ **智能管理工具** - 一键操作  
✅ **完整文档支持** - 详细使用指南  

## 📚 更多资源

- 📘 [详细API对接指南](API_INTEGRATION_GUIDE.md)
- 📊 [完整总结文档](API_INTEGRATION_SUMMARY.md)
- 📗 [实时API文档](REALTIME_API_DOCS.md)
- 🔧 [客户端示例代码](api_integration/client_examples.py)

---

**🚀 现在就开始使用您的实时数据API吧！**

```bash
# 一键安装命令
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/ONE_CLICK_INSTALL.sh)
```

**您的数据，您的掌控！** 💪 