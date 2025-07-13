#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XrayR URL Logger 客户端对接示例
展示如何通过不同方式获取实时数据

包含：
1. HTTP REST API 客户端
2. WebSocket 实时客户端
3. 直接TCP连接客户端
4. 数据处理和存储示例
"""

import requests
import websocket
import socket
import json
import threading
import time
from datetime import datetime
import sqlite3
import asyncio

class HTTPAPIClient:
    """HTTP REST API 客户端"""
    
    def __init__(self, base_url='http://localhost:8080'):
        self.base_url = base_url
        
    def get_latest_records(self, limit=100, user_filter=None, domain_filter=None):
        """获取最新访问记录"""
        params = {'limit': limit}
        if user_filter:
            params['user'] = user_filter
        if domain_filter:
            params['domain'] = domain_filter
            
        try:
            response = requests.get(f"{self.base_url}/api/records", params=params)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"HTTP API错误: {e}")
            return None
    
    def get_stats(self):
        """获取统计信息"""
        try:
            response = requests.get(f"{self.base_url}/api/stats")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"获取统计失败: {e}")
            return None
    
    def health_check(self):
        """健康检查"""
        try:
            response = requests.get(f"{self.base_url}/api/health")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"健康检查失败: {e}")
            return None

class WebSocketClient:
    """WebSocket 实时客户端"""
    
    def __init__(self, url='ws://localhost:8081/ws'):
        self.url = url
        self.ws = None
        self.running = False
        
    def connect(self, on_message=None):
        """连接WebSocket"""
        def on_open(ws):
            print("WebSocket连接成功")
            self.running = True
            
        def on_close(ws, close_status_code, close_msg):
            print("WebSocket连接关闭")
            self.running = False
            
        def on_error(ws, error):
            print(f"WebSocket错误: {error}")
            
        def on_msg(ws, message):
            try:
                data = json.loads(message)
                if on_message:
                    on_message(data)
                else:
                    print(f"收到数据: {data}")
            except json.JSONDecodeError:
                print(f"无效JSON: {message}")
        
        websocket.enableTrace(True)
        self.ws = websocket.WebSocketApp(
            self.url,
            on_open=on_open,
            on_message=on_msg,
            on_error=on_error,
            on_close=on_close
        )
        
        # 启动连接
        self.ws.run_forever()
    
    def close(self):
        """关闭连接"""
        if self.ws:
            self.running = False
            self.ws.close()

class TCPDirectClient:
    """直接TCP连接客户端"""
    
    def __init__(self, host='localhost', port=9999):
        self.host = host
        self.port = port
        self.socket = None
        self.running = False
        
    def connect(self, on_data=None):
        """连接TCP服务器"""
        try:
            self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.socket.connect((self.host, self.port))
            print(f"TCP连接成功: {self.host}:{self.port}")
            
            self.running = True
            buffer = ""
            
            while self.running:
                data = self.socket.recv(4096).decode('utf-8')
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
                                if on_data:
                                    on_data(message['data'])
                                else:
                                    print(f"TCP数据: {message['data']}")
                        except json.JSONDecodeError:
                            pass
                            
        except Exception as e:
            print(f"TCP连接错误: {e}")
        finally:
            if self.socket:
                self.socket.close()
    
    def close(self):
        """关闭连接"""
        self.running = False
        if self.socket:
            self.socket.close()

class DataProcessor:
    """数据处理器 - 存储到数据库"""
    
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
            node_tag TEXT,
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
            node_id, node_tag, source_ip, user_info, request_time, received_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            data.get('timestamp'),
            data.get('user_id'),
            data.get('email'),
            data.get('domain'),
            data.get('full_url'),
            data.get('protocol'),
            data.get('node_id'),
            data.get('node_tag'),
            data.get('source_ip'),
            data.get('user_info'),
            data.get('request_time'),
            data.get('received_at', datetime.now().isoformat())
        ))
        
        conn.commit()
        conn.close()
        
    def get_records_count(self):
        """获取记录总数"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM url_access')
        count = cursor.fetchone()[0]
        conn.close()
        return count
    
    def get_user_stats(self):
        """获取用户统计"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute('''
        SELECT user_id, email, COUNT(*) as access_count 
        FROM url_access 
        GROUP BY user_id, email 
        ORDER BY access_count DESC 
        LIMIT 10
        ''')
        stats = cursor.fetchall()
        conn.close()
        return stats

# 使用示例
def example_http_api():
    """HTTP API 使用示例"""
    print("=== HTTP API 示例 ===")
    
    client = HTTPAPIClient()
    
    # 健康检查
    health = client.health_check()
    if health:
        print(f"服务状态: {health['status']}")
    
    # 获取最新记录
    records = client.get_latest_records(limit=5)
    if records:
        print(f"获取到 {records['count']} 条记录")
        for record in records['data']:
            print(f"  用户 {record['user_id']} 访问 {record['domain']}")
    
    # 获取统计信息
    stats = client.get_stats()
    if stats:
        print(f"总记录数: {stats['data']['total_records']}")

def example_websocket():
    """WebSocket 使用示例"""
    print("=== WebSocket 示例 ===")
    
    def handle_message(data):
        print(f"实时数据: 用户{data.get('user_id')} 访问 {data.get('domain')}")
    
    client = WebSocketClient()
    
    # 在新线程中运行
    thread = threading.Thread(target=lambda: client.connect(handle_message))
    thread.start()
    
    # 运行10秒
    time.sleep(10)
    client.close()

def example_tcp_direct():
    """直接TCP连接示例"""
    print("=== 直接TCP连接示例 ===")
    
    processor = DataProcessor()
    
    def handle_data(data):
        print(f"保存数据: 用户{data.get('user_id')} 访问 {data.get('domain')}")
        processor.save_record(data)
    
    client = TCPDirectClient()
    
    # 在新线程中运行
    thread = threading.Thread(target=lambda: client.connect(handle_data))
    thread.start()
    
    # 运行10秒
    time.sleep(10)
    client.close()
    
    # 显示统计
    print(f"数据库中共有 {processor.get_records_count()} 条记录")

def example_data_analysis():
    """数据分析示例"""
    print("=== 数据分析示例 ===")
    
    processor = DataProcessor()
    
    # 获取用户访问统计
    user_stats = processor.get_user_stats()
    print("用户访问排行:")
    for user_id, email, count in user_stats:
        print(f"  用户 {user_id} ({email}): {count} 次访问")

if __name__ == '__main__':
    print("XrayR URL Logger 客户端对接示例")
    print("=" * 50)
    
    # 选择要运行的示例
    print("请选择示例:")
    print("1. HTTP API 示例")
    print("2. WebSocket 示例")
    print("3. 直接TCP连接示例")
    print("4. 数据分析示例")
    
    choice = input("请输入选择 (1-4): ")
    
    if choice == '1':
        example_http_api()
    elif choice == '2':
        example_websocket()
    elif choice == '3':
        example_tcp_direct()
    elif choice == '4':
        example_data_analysis()
    else:
        print("无效选择") 