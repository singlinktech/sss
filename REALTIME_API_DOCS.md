# XrayR URL Logger 实时推送 API 文档

## 📡 概述

XrayR URL Logger 提供实时TCP推送服务，监听端口 **9999**，实时推送用户的URL访问记录。支持多客户端同时连接，提供心跳检测和自动重连机制。

## 🔗 连接信息

- **协议**: TCP
- **地址**: 127.0.0.1:9999 (本地监听)
- **数据格式**: JSON (每行一个JSON对象)
- **编码**: UTF-8

## 📋 数据结构

### 消息类型

所有消息都包含 `type` 字段，用于标识消息类型：

#### 1. 欢迎消息 (welcome)
```json
{
  "type": "welcome",
  "message": "XrayR URL实时推送服务",
  "time": "2025-07-14T04:30:58+08:00"
}
```

#### 2. 心跳消息 (heartbeat)
```json
{
  "type": "heartbeat",
  "time": "2025-07-14T04:30:58+08:00"
}
```

#### 3. URL访问记录 (url_access)
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

### 字段说明

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `timestamp` | string | ISO 8601格式的时间戳 |
| `user_id` | int | 用户真实ID |
| `email` | string | 用户邮箱 (通常是UUID格式) |
| `domain` | string | 访问的域名 |
| `full_url` | string | 完整URL (如果启用) |
| `protocol` | string | 协议类型 (http, https, tls等) |
| `node_id` | int | 节点ID |
| `node_tag` | string | 节点标签 |
| `source_ip` | string | 用户源IP地址 |
| `user_info` | string | 额外用户信息 |
| `request_time` | string | 格式化的请求时间 |

## 🔧 客户端示例

### Python 客户端 (推荐)

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XrayR URL Logger 实时监控客户端
"""

import socket
import json
import time
from datetime import datetime
import threading

class XrayRMonitor:
    def __init__(self, host='127.0.0.1', port=9999):
        self.host = host
        self.port = port
        self.socket = None
        self.running = False
        
    def connect(self):
        """连接到XrayR实时推送服务器"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.host, self.port))
            self.socket.settimeout(60)  # 60秒超时
            print(f"✅ 已连接到 {self.host}:{self.port}")
            return True
        except Exception as e:
            print(f"❌ 连接失败: {e}")
            return False
    
    def disconnect(self):
        """断开连接"""
        self.running = False
        if self.socket:
            self.socket.close()
            self.socket = None
        print("🔌 已断开连接")
    
    def start_monitoring(self, callback=None):
        """开始监控"""
        if not self.connect():
            return
        
        self.running = True
        buffer = ""
        
        try:
            while self.running:
                data = self.socket.recv(4096).decode('utf-8')
                if not data:
                    break
                
                buffer += data
                lines = buffer.split('\n')
                buffer = lines[-1]  # 保留不完整的行
                
                for line in lines[:-1]:
                    if line.strip():
                        try:
                            message = json.loads(line.strip())
                            self.handle_message(message, callback)
                        except json.JSONDecodeError as e:
                            print(f"⚠️ JSON解析错误: {e}")
                            
        except socket.timeout:
            print("⏰ 连接超时")
        except Exception as e:
            print(f"❌ 监控错误: {e}")
        finally:
            self.disconnect()
    
    def handle_message(self, message, callback=None):
        """处理接收到的消息"""
        msg_type = message.get('type', 'unknown')
        
        if msg_type == 'welcome':
            print(f"🎉 {message.get('message', '')}")
            
        elif msg_type == 'heartbeat':
            print(f"💓 心跳: {message.get('time', '')}")
            
        elif msg_type == 'url_access':
            data = message.get('data', {})
            self.display_url_access(data)
            
            # 调用自定义回调函数
            if callback:
                callback(data)
        
        else:
            print(f"❓ 未知消息类型: {msg_type}")
    
    def display_url_access(self, data):
        """格式化显示URL访问记录"""
        print("\n" + "="*60)
        print(f"🌐 URL访问记录")
        print("="*60)
        print(f"⏰ 时间: {data.get('request_time', '')}")
        print(f"👤 用户: {data.get('email', '')} (ID: {data.get('user_id', '')})")
        print(f"🎯 访问: {data.get('domain', '')}")
        print(f"📍 来源: {data.get('source_ip', '')}")
        print(f"🔗 协议: {data.get('protocol', '')}")
        print(f"🏷️ 节点: {data.get('node_tag', '')} (ID: {data.get('node_id', '')})")
        if data.get('full_url'):
            print(f"🌍 完整URL: {data.get('full_url', '')}")
        print("="*60)

def custom_handler(data):
    """自定义处理函数示例"""
    # 这里可以添加你的自定义逻辑
    # 例如：存入数据库、发送告警、写入文件等
    
    # 示例：记录可疑访问
    suspicious_domains = ['malware.com', 'phishing.net', 'virus.org']
    domain = data.get('domain', '')
    
    if any(sus in domain for sus in suspicious_domains):
        print(f"🚨 可疑访问: 用户 {data.get('user_id')} 访问了 {domain}")
        # 这里可以添加告警逻辑

def main():
    """主程序"""
    print("XrayR URL Logger 实时监控客户端")
    print("按 Ctrl+C 退出")
    
    monitor = XrayRMonitor()
    
    try:
        monitor.start_monitoring(callback=custom_handler)
    except KeyboardInterrupt:
        print("\n👋 用户终止程序")
    except Exception as e:
        print(f"❌ 程序错误: {e}")
    finally:
        monitor.disconnect()

if __name__ == "__main__":
    main()
```

### JavaScript (Node.js) 客户端

```javascript
const net = require('net');

class XrayRMonitor {
    constructor(host = '127.0.0.1', port = 9999) {
        this.host = host;
        this.port = port;
        this.client = null;
        this.running = false;
    }

    connect() {
        return new Promise((resolve, reject) => {
            this.client = net.createConnection({ host: this.host, port: this.port }, () => {
                console.log(`✅ 已连接到 ${this.host}:${this.port}`);
                resolve();
            });

            this.client.on('error', (err) => {
                console.error(`❌ 连接错误: ${err.message}`);
                reject(err);
            });

            this.client.on('close', () => {
                console.log('🔌 连接已关闭');
                this.running = false;
            });
        });
    }

    startMonitoring(callback) {
        this.running = true;
        let buffer = '';

        this.client.on('data', (data) => {
            buffer += data.toString();
            const lines = buffer.split('\n');
            buffer = lines.pop(); // 保留不完整的行

            lines.forEach(line => {
                if (line.trim()) {
                    try {
                        const message = JSON.parse(line.trim());
                        this.handleMessage(message, callback);
                    } catch (e) {
                        console.error(`⚠️ JSON解析错误: ${e.message}`);
                    }
                }
            });
        });
    }

    handleMessage(message, callback) {
        const msgType = message.type || 'unknown';

        switch (msgType) {
            case 'welcome':
                console.log(`🎉 ${message.message || ''}`);
                break;
            
            case 'heartbeat':
                console.log(`💓 心跳: ${message.time || ''}`);
                break;
            
            case 'url_access':
                const data = message.data || {};
                this.displayUrlAccess(data);
                if (callback) callback(data);
                break;
            
            default:
                console.log(`❓ 未知消息类型: ${msgType}`);
        }
    }

    displayUrlAccess(data) {
        console.log('\n' + '='.repeat(60));
        console.log('🌐 URL访问记录');
        console.log('='.repeat(60));
        console.log(`⏰ 时间: ${data.request_time || ''}`);
        console.log(`👤 用户: ${data.email || ''} (ID: ${data.user_id || ''})`);
        console.log(`🎯 访问: ${data.domain || ''}`);
        console.log(`📍 来源: ${data.source_ip || ''}`);
        console.log(`🔗 协议: ${data.protocol || ''}`);
        console.log(`🏷️ 节点: ${data.node_tag || ''} (ID: ${data.node_id || ''})`);
        if (data.full_url) {
            console.log(`🌍 完整URL: ${data.full_url}`);
        }
        console.log('='.repeat(60));
    }

    disconnect() {
        this.running = false;
        if (this.client) {
            this.client.end();
        }
    }
}

// 使用示例
async function main() {
    const monitor = new XrayRMonitor();
    
    try {
        await monitor.connect();
        monitor.startMonitoring((data) => {
            // 自定义处理逻辑
            console.log(`📊 处理用户 ${data.user_id} 的访问记录`);
        });
    } catch (error) {
        console.error('连接失败:', error.message);
    }

    // 优雅退出
    process.on('SIGINT', () => {
        console.log('\n👋 程序退出');
        monitor.disconnect();
        process.exit(0);
    });
}

main().catch(console.error);
```

### Go 客户端

```go
package main

import (
    "bufio"
    "encoding/json"
    "fmt"
    "net"
    "os"
    "os/signal"
    "syscall"
    "time"
)

type Message struct {
    Type string                 `json:"type"`
    Data map[string]interface{} `json:"data,omitempty"`
    Time string                 `json:"time,omitempty"`
    Message string              `json:"message,omitempty"`
}

type XrayRMonitor struct {
    host string
    port string
    conn net.Conn
}

func NewXrayRMonitor(host, port string) *XrayRMonitor {
    return &XrayRMonitor{
        host: host,
        port: port,
    }
}

func (m *XrayRMonitor) Connect() error {
    conn, err := net.Dial("tcp", m.host+":"+m.port)
    if err != nil {
        return fmt.Errorf("连接失败: %v", err)
    }
    
    m.conn = conn
    fmt.Printf("✅ 已连接到 %s:%s\n", m.host, m.port)
    return nil
}

func (m *XrayRMonitor) StartMonitoring() error {
    scanner := bufio.NewScanner(m.conn)
    
    for scanner.Scan() {
        line := scanner.Text()
        if line == "" {
            continue
        }
        
        var message Message
        if err := json.Unmarshal([]byte(line), &message); err != nil {
            fmt.Printf("⚠️ JSON解析错误: %v\n", err)
            continue
        }
        
        m.handleMessage(message)
    }
    
    return scanner.Err()
}

func (m *XrayRMonitor) handleMessage(message Message) {
    switch message.Type {
    case "welcome":
        fmt.Printf("🎉 %s\n", message.Message)
    case "heartbeat":
        fmt.Printf("💓 心跳: %s\n", message.Time)
    case "url_access":
        m.displayUrlAccess(message.Data)
    default:
        fmt.Printf("❓ 未知消息类型: %s\n", message.Type)
    }
}

func (m *XrayRMonitor) displayUrlAccess(data map[string]interface{}) {
    fmt.Println("\n" + strings.Repeat("=", 60))
    fmt.Println("🌐 URL访问记录")
    fmt.Println(strings.Repeat("=", 60))
    fmt.Printf("⏰ 时间: %v\n", data["request_time"])
    fmt.Printf("👤 用户: %v (ID: %v)\n", data["email"], data["user_id"])
    fmt.Printf("🎯 访问: %v\n", data["domain"])
    fmt.Printf("📍 来源: %v\n", data["source_ip"])
    fmt.Printf("🔗 协议: %v\n", data["protocol"])
    fmt.Printf("🏷️ 节点: %v (ID: %v)\n", data["node_tag"], data["node_id"])
    if fullURL, ok := data["full_url"].(string); ok && fullURL != "" {
        fmt.Printf("🌍 完整URL: %s\n", fullURL)
    }
    fmt.Println(strings.Repeat("=", 60))
}

func (m *XrayRMonitor) Close() {
    if m.conn != nil {
        m.conn.Close()
        fmt.Println("🔌 已断开连接")
    }
}

func main() {
    monitor := NewXrayRMonitor("127.0.0.1", "9999")
    
    if err := monitor.Connect(); err != nil {
        fmt.Printf("❌ %v\n", err)
        return
    }
    defer monitor.Close()
    
    // 处理退出信号
    c := make(chan os.Signal, 1)
    signal.Notify(c, os.Interrupt, syscall.SIGTERM)
    
    go func() {
        <-c
        fmt.Println("\n👋 程序退出")
        monitor.Close()
        os.Exit(0)
    }()
    
    fmt.Println("开始监控... 按 Ctrl+C 退出")
    if err := monitor.StartMonitoring(); err != nil {
        fmt.Printf("❌ 监控错误: %v\n", err)
    }
}
```

### Bash 脚本客户端

```bash
#!/bin/bash
# XrayR URL Logger 实时监控脚本

HOST="127.0.0.1"
PORT="9999"

echo "🔗 连接到 $HOST:$PORT"
echo "📊 开始监控URL访问... 按 Ctrl+C 退出"

# 使用nc (netcat) 连接并处理数据
exec 3<>/dev/tcp/$HOST/$PORT

while IFS= read -r line <&3; do
    # 检查是否为空行
    if [[ -z "$line" ]]; then
        continue
    fi
    
    # 解析JSON (需要jq工具)
    type=$(echo "$line" | jq -r '.type // empty')
    
    case "$type" in
        "welcome")
            message=$(echo "$line" | jq -r '.message // empty')
            echo "🎉 $message"
            ;;
        "heartbeat")
            time=$(echo "$line" | jq -r '.time // empty')
            echo "💓 心跳: $time"
            ;;
        "url_access")
            echo ""
            echo "============================================================"
            echo "🌐 URL访问记录"
            echo "============================================================"
            echo "⏰ 时间: $(echo "$line" | jq -r '.data.request_time // empty')"
            echo "👤 用户: $(echo "$line" | jq -r '.data.email // empty') (ID: $(echo "$line" | jq -r '.data.user_id // empty'))"
            echo "🎯 访问: $(echo "$line" | jq -r '.data.domain // empty')"
            echo "📍 来源: $(echo "$line" | jq -r '.data.source_ip // empty')"
            echo "🔗 协议: $(echo "$line" | jq -r '.data.protocol // empty')"
            echo "🏷️ 节点: $(echo "$line" | jq -r '.data.node_tag // empty') (ID: $(echo "$line" | jq -r '.data.node_id // empty'))"
            full_url=$(echo "$line" | jq -r '.data.full_url // empty')
            if [[ -n "$full_url" ]]; then
                echo "🌍 完整URL: $full_url"
            fi
            echo "============================================================"
            ;;
        *)
            echo "❓ 未知消息: $line"
            ;;
    esac
done

exec 3<&-
exec 3>&-
```

## 🚀 快速开始

### 1. 检查服务状态
```bash
# 检查XrayR服务是否运行
systemctl status xrayr

# 检查端口9999是否监听
lsof -i :9999
```

### 2. 使用Python客户端 (推荐)
```bash
# 保存上面的Python代码为 monitor.py
chmod +x monitor.py
python3 monitor.py
```

### 3. 使用已编译的监控工具
```bash
# 使用内置的监控工具（格式化显示）
xrayr-monitor

# 使用JSON监控工具（纯JSON输出）
xrayr-json-monitor

# 使用简单JSON监控工具（bash版本）
xrayr-json-simple
```

### 4. 简单测试连接
```bash
# 使用telnet测试连接
telnet 127.0.0.1 9999

# 使用nc测试连接
nc 127.0.0.1 9999
```

## 📋 纯JSON输出

如果您只需要JSON格式的数据（用于API集成或脚本处理），可以使用专门的JSON监控工具：

### 使用Python JSON监控器
```bash
# 直接输出JSON格式
xrayr-json-monitor

# 保存到文件
xrayr-json-monitor > /tmp/access.json

# 结合jq处理
xrayr-json-monitor | jq '.data.domain'

# 过滤特定用户
xrayr-json-monitor | jq 'select(.data.user_id == 23)'
```

### 使用Bash JSON监控器
```bash
# 简单版本，无Python依赖
xrayr-json-simple

# 配合其他工具使用
xrayr-json-simple | grep "google.com"
```

### JSON输出示例
每行输出一个完整的JSON对象：
```json
{"type":"url_access","data":{"timestamp":"2025-07-14T04:30:58.464805348+08:00","user_id":23,"email":"a9d727cd-330b-4edd-8911-7c224df6afd5@v2board.user","domain":"m.baidu.com","full_url":"https://m.baidu.com:443","protocol":"tls","node_id":28,"node_tag":"Shadowsocks_0.0.0.0_23999","source_ip":"218.252.250.102","user_info":"level:0,tag:Shadowsocks_0.0.0.0_23999,network:tcp","request_time":"2025-07-14 04:30:58"}}
```

## 🔧 高级用法

### WebSocket代理 (可选)
如果需要在Web界面中显示实时数据，可以创建WebSocket代理：

```javascript
// websocket-proxy.js
const WebSocket = require('ws');
const net = require('net');

const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
    console.log('WebSocket客户端连接');
    
    const tcpClient = net.createConnection({ host: '127.0.0.1', port: 9999 });
    
    tcpClient.on('data', (data) => {
        const lines = data.toString().split('\n');
        lines.forEach(line => {
            if (line.trim()) {
                ws.send(line.trim());
            }
        });
    });
    
    ws.on('close', () => {
        tcpClient.end();
        console.log('WebSocket客户端断开');
    });
    
    tcpClient.on('error', (err) => {
        console.error('TCP连接错误:', err.message);
        ws.close();
    });
});

console.log('WebSocket代理服务器启动在端口 8080');
```

### HTTP API (可选)
如果需要HTTP接口获取数据，可以创建简单的HTTP API：

```python
from flask import Flask, jsonify, stream_template
import socket
import json
import threading
import queue

app = Flask(__name__)
data_queue = queue.Queue(maxsize=100)

def tcp_listener():
    """TCP数据监听器"""
    while True:
        try:
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
                        try:
                            message = json.loads(line.strip())
                            if message.get('type') == 'url_access':
                                data_queue.put(message['data'])
                        except:
                            pass
        except Exception as e:
            print(f"TCP监听错误: {e}")
            time.sleep(5)

@app.route('/api/latest')
def get_latest():
    """获取最新的访问记录"""
    records = []
    while not data_queue.empty() and len(records) < 10:
        try:
            records.append(data_queue.get_nowait())
        except queue.Empty:
            break
    return jsonify(records)

# 启动TCP监听线程
threading.Thread(target=tcp_listener, daemon=True).start()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

## 📞 技术支持

如果遇到问题：

1. **检查服务状态**: `systemctl status xrayr`
2. **查看日志**: `journalctl -u xrayr -f`
3. **检查端口**: `lsof -i :9999`
4. **测试连接**: `telnet 127.0.0.1 9999`

## 🔄 安装脚本

使用一键安装脚本：
```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)
``` 