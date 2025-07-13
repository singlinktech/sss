# XrayR URL访问实时推送功能

## 概述

URL访问实时推送功能是XrayR的一个扩展功能，它允许你通过TCP连接实时接收用户的URL访问记录。这个功能特别适合需要实时监控和分析用户访问行为的场景。

## 特性

- **实时推送**：URL访问记录会立即推送给所有连接的客户端
- **完整信息**：包含用户的所有信息（邮箱、ID、源IP等）
- **简单协议**：使用JSON格式，易于解析
- **自动启动**：随XrayR自动启动，无需额外操作
- **多客户端**：支持多个客户端同时连接
- **心跳机制**：自动检测连接状态

## 配置方法

在XrayR的配置文件中，在`URLLoggerConfig`部分添加实时推送配置：

```yaml
ControllerConfig:
  URLLoggerConfig:
    Enable: true                    # 必须启用URL记录器
    EnableRealtime: true            # 启用实时推送
    RealtimeAddr: "127.0.0.1:9999"  # 监听地址和端口
```

### 配置说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `EnableRealtime` | bool | false | 是否启用实时推送功能 |
| `RealtimeAddr` | string | "127.0.0.1:9999" | TCP监听地址，格式为 "IP:端口" |

## 数据格式

### 消息类型

实时推送服务器会发送三种类型的消息：

1. **欢迎消息** - 客户端连接时发送
```json
{
  "type": "welcome",
  "message": "XrayR URL实时推送服务",
  "time": "2024-07-14T12:00:00Z"
}
```

2. **心跳消息** - 每30秒发送一次
```json
{
  "type": "heartbeat",
  "time": "2024-07-14T12:00:30Z"
}
```

3. **URL访问记录** - 用户访问URL时发送
```json
{
  "type": "url_access",
  "data": {
    "timestamp": "2024-07-14T12:00:15Z",
    "user_id": 0,
    "email": "user@example.com",
    "domain": "google.com",
    "full_url": "https://google.com:443",
    "protocol": "https",
    "node_id": 1,
    "node_tag": "node1",
    "source_ip": "192.168.1.100",
    "user_info": "level:0,tag:node1,network:tcp",
    "request_time": "2024-07-14 12:00:15"
  }
}
```

### 数据字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `timestamp` | string | ISO格式的时间戳 |
| `user_id` | int | 用户ID |
| `email` | string | 用户邮箱 |
| `domain` | string | 访问的域名 |
| `full_url` | string | 完整的URL（包含协议和端口） |
| `protocol` | string | 协议类型（http/https等） |
| `node_id` | int | 节点ID |
| `node_tag` | string | 节点标签 |
| `source_ip` | string | 用户源IP地址 |
| `user_info` | string | 额外的用户信息 |
| `request_time` | string | 请求时间（人类可读格式） |

## 客户端实现

### Python示例

```python
import socket
import json

# 连接到服务器
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect(('127.0.0.1', 9999))

# 接收数据
buffer = ""
while True:
    data = sock.recv(4096).decode('utf-8')
    buffer += data
    lines = buffer.split('\n')
    buffer = lines[-1]
    
    for line in lines[:-1]:
        if line.strip():
            msg = json.loads(line)
            if msg['type'] == 'url_access':
                # 处理URL访问记录
                print(f"用户 {msg['data']['email']} 访问了 {msg['data']['domain']}")
```

### Node.js示例

```javascript
const net = require('net');

const client = net.createConnection({ port: 9999, host: '127.0.0.1' }, () => {
  console.log('连接到服务器');
});

let buffer = '';
client.on('data', (data) => {
  buffer += data.toString();
  const lines = buffer.split('\n');
  buffer = lines.pop();
  
  lines.forEach(line => {
    if (line.trim()) {
      const msg = JSON.parse(line);
      if (msg.type === 'url_access') {
        console.log(`用户 ${msg.data.email} 访问了 ${msg.data.domain}`);
      }
    }
  });
});
```

### Go示例

```go
package main

import (
    "bufio"
    "encoding/json"
    "fmt"
    "net"
)

type Message struct {
    Type string                 `json:"type"`
    Data map[string]interface{} `json:"data"`
}

func main() {
    conn, err := net.Dial("tcp", "127.0.0.1:9999")
    if err != nil {
        panic(err)
    }
    defer conn.Close()

    scanner := bufio.NewScanner(conn)
    for scanner.Scan() {
        var msg Message
        if err := json.Unmarshal(scanner.Bytes(), &msg); err == nil {
            if msg.Type == "url_access" {
                fmt.Printf("用户 %s 访问了 %s\n", 
                    msg.Data["email"], msg.Data["domain"])
            }
        }
    }
}
```

## 使用场景

1. **实时监控**：监控用户访问的网站，及时发现异常行为
2. **数据分析**：实时分析用户访问模式
3. **安全审计**：记录和审计用户的网络访问
4. **告警系统**：当用户访问特定网站时触发告警
5. **统计分析**：实时统计热门网站访问

## 性能考虑

- 实时推送使用内存缓冲区，避免阻塞主流程
- 当缓冲区满时，新消息会被丢弃（避免内存溢出）
- 每个连接使用独立的goroutine处理
- 支持多客户端并发连接

## 安全建议

1. **监听地址**：建议只监听本地地址（127.0.0.1）
2. **访问控制**：如需远程访问，请使用防火墙限制访问IP
3. **数据加密**：如需通过网络传输，建议使用SSH隧道或VPN
4. **权限控制**：确保只有授权的程序可以连接

## 故障排除

### 无法连接到服务器

1. 检查XrayR是否正在运行
2. 检查URLLoggerConfig是否启用
3. 检查EnableRealtime是否设置为true
4. 检查端口是否被占用：`lsof -i :9999`

### 没有收到数据

1. 检查是否有用户正在使用代理
2. 查看XrayR日志是否有错误
3. 确认ExcludeDomains没有排除所有域名

### 连接经常断开

1. 检查网络稳定性
2. 查看XrayR是否频繁重启
3. 检查客户端代码是否正确处理心跳

## 完整示例

### 配置文件

```yaml
Log:
  Level: info

Nodes:
  - PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "https://your-panel.com"
      ApiKey: "your-api-key"
      NodeID: 1
      NodeType: V2ray
    ControllerConfig:
      URLLoggerConfig:
        Enable: true
        LogPath: "/var/log/xrayr/url_access.log"
        EnableRealtime: true
        RealtimeAddr: "127.0.0.1:9999"
```

### 运行客户端

```bash
# Python客户端
python3 examples/realtime_client.py

# 或指定服务器地址
python3 examples/realtime_client.py 192.168.1.100 9999
```

### 输出示例

```
XrayR URL访问实时推送客户端
连接到 127.0.0.1:9999
------------------------------------------------------------
[2024-07-14 12:00:00] 成功连接到服务器 127.0.0.1:9999
[服务器] XrayR URL实时推送服务

============================================================
[URL访问记录] 2024-07-14 12:00:15
用户邮箱: user@example.com
用户ID: 0
源IP: 192.168.1.100
访问域名: google.com
完整URL: https://google.com:443
协议: https
节点ID: 1
节点标签: node1
额外信息: level:0,tag:node1,network:tcp
============================================================
```

## 总结

实时推送功能提供了一种简单、高效的方式来实时获取用户的URL访问记录。通过TCP连接和JSON格式，任何编程语言都可以轻松接入。这个功能完全集成在XrayR中，无需额外的服务或配置，真正做到了开箱即用。 