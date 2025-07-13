# 🎯 XrayR 实时数据API对接 - 完整总结

## 📋 您的需求理解

您想要：
1. ✅ **实时获取**用户访问数据（不是读取文件）
2. ✅ **数据不保存**在节点服务器上（避免硬盘爆满）
3. ✅ **API接口获取**，让您的服务器处理和存储
4. ✅ **灵活对接**，适用于不同场景

## 🚀 解决方案概览

我们提供了**3种对接方式**，您可以根据需要选择：

### 🔥 方案对比

| 方案 | 延迟 | 复杂度 | 适用场景 | 推荐指数 |
|------|------|--------|----------|----------|
| **直接TCP** | 最低 | 简单 | 高性能场景 | ⭐⭐⭐⭐⭐ |
| **HTTP API** | 中等 | 中等 | 标准化集成 | ⭐⭐⭐⭐ |
| **WebSocket** | 低 | 中等 | 实时监控 | ⭐⭐⭐⭐ |

## 📝 第一步：配置XrayR纯实时模式

### 1. 修改配置文件

编辑 `/etc/xrayr/config.yml` 或您的配置文件：

```yaml
# 🔥 关键配置 - 纯实时推送模式
URLLoggerConfig:
  Enable: true                    # 启用URL记录器
  LogPath: ""                     # 🔥 留空 = 不保存文件
  MaxFileSize: 0                  # 🔥 0 = 不保存文件
  MaxFileCount: 0                 # 🔥 0 = 不保存文件
  FlushInterval: 1                # 1秒立即推送
  EnableRealtime: true            # 🔥 启用实时推送
  RealtimeAddr: "0.0.0.0:9999"   # 🔥 监听所有网络接口
  EnableFullURL: true             # 记录完整URL
  ExcludeDomains:                 # 排除不需要的域名
    - "localhost"
    - "127.0.0.1"
    - "apple.com"
    - "icloud.com"
```

### 2. 重启XrayR

```bash
systemctl restart xrayr
```

### 3. 验证配置

```bash
# 查看日志，应该看到：
journalctl -u xrayr -f

# 输出示例：
# "URL记录器运行在纯实时推送模式（不保存文件）"
# "实时推送服务器已启动，监听端口: 9999"
```

## 🌐 第二步：选择对接方式

### 方式1: 直接TCP连接（最简单，推荐）

**优点**: 最低延迟，直接获取数据，无需中间件
**缺点**: 需要处理TCP连接

#### Python示例

```python
import socket
import json
import time

def connect_xrayr_realtime():
    """连接XrayR实时数据"""
    while True:
        try:
            # 连接到XrayR实时推送端口
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect(('你的XrayR服务器IP', 9999))
            
            print("✅ 连接成功，等待数据...")
            
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
                                # 🔥 在这里处理数据
                                process_url_access(message['data'])
                        except json.JSONDecodeError:
                            pass
                            
        except Exception as e:
            print(f"连接错误: {e}")
            time.sleep(5)  # 5秒后重连

def process_url_access(data):
    """处理URL访问数据"""
    print(f"用户 {data['user_id']} 访问了 {data['domain']}")
    
    # 🔥 在这里添加您的业务逻辑
    # 例如：保存到数据库、发送到API、触发告警等
    save_to_database(data)
    send_to_api(data)
    check_security(data)

def save_to_database(data):
    """保存到数据库"""
    # 您的数据库操作代码
    pass

def send_to_api(data):
    """发送到您的API"""
    # 您的API调用代码
    pass

def check_security(data):
    """安全检查"""
    # 您的安全检查逻辑
    pass

# 运行
if __name__ == '__main__':
    connect_xrayr_realtime()
```

### 方式2: HTTP API代理

**优点**: 标准化，易于集成，支持REST API
**缺点**: 需要部署中间件

#### 一键部署

```bash
# 1. 在您的服务器上部署HTTP API代理
curl -O https://raw.githubusercontent.com/singlinktech/sss/main/api_integration/deploy_api.sh
chmod +x deploy_api.sh
./deploy_api.sh

# 2. 检查服务状态
/opt/xrayr-api/manage.sh status
```

#### 使用HTTP API

```python
import requests
import time

def use_http_api():
    """使用HTTP API获取数据"""
    base_url = "http://你的服务器IP:8080"
    
    while True:
        try:
            # 获取最新记录
            response = requests.get(f"{base_url}/api/records?limit=100")
            if response.status_code == 200:
                data = response.json()
                
                for record in data['data']:
                    # 🔥 处理每条记录
                    process_url_access(record)
            
            # 获取统计信息
            response = requests.get(f"{base_url}/api/stats")
            if response.status_code == 200:
                stats = response.json()
                print(f"总访问量: {stats['data']['total_records']}")
            
            time.sleep(5)  # 5秒轮询一次
            
        except Exception as e:
            print(f"API错误: {e}")
            time.sleep(10)

# 运行
if __name__ == '__main__':
    use_http_api()
```

### 方式3: WebSocket实时推送

**优点**: 双向通信，实时性强
**缺点**: 复杂度中等

```python
import websocket
import json
import threading

def on_message(ws, message):
    """收到WebSocket消息"""
    try:
        data = json.loads(message)
        if isinstance(data, dict) and 'user_id' in data:
            # 🔥 处理实时数据
            process_url_access(data)
    except json.JSONDecodeError:
        pass

def on_error(ws, error):
    print(f"WebSocket错误: {error}")

def on_close(ws):
    print("WebSocket连接关闭")

def on_open(ws):
    print("WebSocket连接成功")

def use_websocket():
    """使用WebSocket获取实时数据"""
    ws = websocket.WebSocketApp("ws://你的服务器IP:8081/ws",
                                on_message=on_message,
                                on_error=on_error,
                                on_close=on_close,
                                on_open=on_open)
    ws.run_forever()

# 运行
if __name__ == '__main__':
    use_websocket()
```

## 📊 数据格式说明

### 您会收到的数据结构

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

### 字段解释

- `timestamp`: 访问时间戳
- `user_id`: 用户ID
- `email`: 用户邮箱
- `domain`: 访问的域名
- `full_url`: 完整URL
- `protocol`: 协议类型
- `node_id`: 节点ID
- `source_ip`: 用户真实IP
- `user_info`: 用户额外信息

## 🔧 完整示例：存储到数据库

### SQLite版本

```python
import sqlite3
import json
import socket
import threading
from datetime import datetime

class URLDataProcessor:
    def __init__(self, db_path='url_access.db'):
        self.db_path = db_path
        self.init_database()
        
    def init_database(self):
        """初始化数据库"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS url_access (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT,
                user_id INTEGER,
                email TEXT,
                domain TEXT,
                full_url TEXT,
                protocol TEXT,
                node_id INTEGER,
                source_ip TEXT,
                user_info TEXT,
                request_time TEXT,
                received_at TEXT
            )
        ''')
        
        # 创建索引
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_timestamp ON url_access(timestamp)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_user_id ON url_access(user_id)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_domain ON url_access(domain)')
        
        conn.commit()
        conn.close()
        print(f"数据库初始化完成: {self.db_path}")
        
    def save_record(self, data):
        """保存记录到数据库"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO url_access (
                timestamp, user_id, email, domain, full_url, protocol,
                node_id, source_ip, user_info, request_time, received_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            data.get('timestamp'),
            data.get('user_id'),
            data.get('email'),
            data.get('domain'),
            data.get('full_url'),
            data.get('protocol'),
            data.get('node_id'),
            data.get('source_ip'),
            data.get('user_info'),
            data.get('request_time'),
            datetime.now().isoformat()
        ))
        
        conn.commit()
        conn.close()
        
    def get_stats(self):
        """获取统计信息"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # 总记录数
        cursor.execute('SELECT COUNT(*) FROM url_access')
        total_records = cursor.fetchone()[0]
        
        # 用户统计
        cursor.execute('''
            SELECT user_id, email, COUNT(*) as count 
            FROM url_access 
            GROUP BY user_id, email 
            ORDER BY count DESC 
            LIMIT 10
        ''')
        top_users = cursor.fetchall()
        
        # 域名统计
        cursor.execute('''
            SELECT domain, COUNT(*) as count 
            FROM url_access 
            GROUP BY domain 
            ORDER BY count DESC 
            LIMIT 10
        ''')
        top_domains = cursor.fetchall()
        
        conn.close()
        
        return {
            'total_records': total_records,
            'top_users': top_users,
            'top_domains': top_domains
        }

# 使用示例
processor = URLDataProcessor()

def connect_and_process():
    """连接并处理数据"""
    while True:
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect(('你的XrayR服务器IP', 9999))
            
            print("✅ 连接成功，开始处理数据...")
            
            buffer = ""
            record_count = 0
            
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
                                # 保存到数据库
                                processor.save_record(message['data'])
                                record_count += 1
                                
                                # 每100条记录显示一次统计
                                if record_count % 100 == 0:
                                    stats = processor.get_stats()
                                    print(f"已处理 {record_count} 条记录，"
                                          f"数据库总计 {stats['total_records']} 条")
                                    
                        except json.JSONDecodeError:
                            pass
                            
        except Exception as e:
            print(f"连接错误: {e}")
            time.sleep(5)

# 运行
if __name__ == '__main__':
    connect_and_process()
```

## 🚀 快速测试

### 1. 一键测试脚本

```bash
# 下载测试脚本
curl -O https://raw.githubusercontent.com/singlinktech/sss/main/api_integration/quick_start.sh
chmod +x quick_start.sh

# 运行测试
./quick_start.sh
```

### 2. 手动测试

```bash
# 测试TCP连接
telnet 你的XrayR服务器IP 9999

# 测试HTTP API（需要先部署）
curl "http://你的服务器IP:8080/api/health"
curl "http://你的服务器IP:8080/api/records?limit=5"
```

## 📊 性能优化建议

### 1. 高并发处理

```python
import asyncio
import aioredis
from concurrent.futures import ThreadPoolExecutor

class AsyncURLProcessor:
    def __init__(self):
        self.redis_pool = None
        self.executor = ThreadPoolExecutor(max_workers=10)
        
    async def init_redis(self):
        self.redis_pool = await aioredis.create_redis_pool('redis://localhost')
        
    async def process_data_async(self, data):
        """异步处理数据"""
        # 异步保存到Redis
        await self.redis_pool.hset('user_stats', data['user_id'], 
                                   await self.redis_pool.hget('user_stats', data['user_id']) or 0 + 1)
        
        # 异步保存到数据库
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(self.executor, self.save_to_db, data)
        
    def save_to_db(self, data):
        """同步数据库操作"""
        # 您的数据库操作
        pass
```

### 2. 内存优化

```python
from collections import deque
import gc

class MemoryOptimizedProcessor:
    def __init__(self, max_records=10000):
        self.records = deque(maxlen=max_records)  # 限制内存使用
        self.batch_size = 100
        self.batch_buffer = []
        
    def process_record(self, data):
        """批量处理记录"""
        self.batch_buffer.append(data)
        
        if len(self.batch_buffer) >= self.batch_size:
            self.flush_batch()
            
    def flush_batch(self):
        """批量刷新"""
        # 批量保存到数据库
        self.save_batch_to_db(self.batch_buffer)
        
        # 清空缓冲区
        self.batch_buffer.clear()
        
        # 强制垃圾回收
        gc.collect()
```

## 🔧 部署到生产环境

### 1. 使用Docker

```yaml
# docker-compose.yml
version: '3.8'

services:
  url-processor:
    build: .
    environment:
      - XRAYR_HOST=你的XrayR服务器IP
      - XRAYR_PORT=9999
      - DATABASE_URL=postgresql://user:pass@db:5432/urldb
    depends_on:
      - db
      - redis
    restart: unless-stopped
    
  db:
    image: postgres:14
    environment:
      POSTGRES_DB: urldb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    
  redis:
    image: redis:7-alpine
    restart: unless-stopped

volumes:
  postgres_data:
```

### 2. 系统服务

```ini
# /etc/systemd/system/url-processor.service
[Unit]
Description=URL Access Processor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/url-processor
ExecStart=/usr/bin/python3 /opt/url-processor/main.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 📞 获取帮助

### 常见问题

1. **收不到数据？**
   - 检查XrayR服务状态
   - 确认URL记录器已启用
   - 检查端口9999是否开放

2. **数据延迟高？**
   - 使用直接TCP连接
   - 检查网络延迟
   - 优化处理逻辑

3. **内存占用高？**
   - 使用批量处理
   - 限制内存缓冲区大小
   - 定期清理数据

### 技术支持

- 📧 GitHub Issues: https://github.com/singlinktech/sss/issues
- 📖 完整文档: API_INTEGRATION_GUIDE.md
- 🔧 示例代码: api_integration/client_examples.py

## 🎉 总结

您现在拥有了完整的实时数据API对接方案：

1. ✅ **配置完成** - XrayR纯实时推送模式
2. ✅ **多种选择** - TCP/HTTP/WebSocket 三种对接方式
3. ✅ **完整示例** - 数据库存储、API调用、安全检查
4. ✅ **生产就绪** - Docker部署、系统服务、性能优化
5. ✅ **技术支持** - 详细文档、示例代码、问题解答

**开始使用吧！** 🚀

```bash
# 立即开始
curl -O https://raw.githubusercontent.com/singlinktech/sss/main/api_integration/quick_start.sh
chmod +x quick_start.sh
./quick_start.sh
```

**您的数据，您的规则！** 💪 