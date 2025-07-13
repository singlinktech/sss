#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XrayR URL Logger HTTP API服务器
将TCP实时数据转换为HTTP REST API和WebSocket接口

功能：
1. HTTP REST API - 获取最新的访问记录
2. WebSocket - 实时推送数据
3. 数据过滤和查询
4. 数据统计接口

使用方法：
python3 http_api_server.py
"""

import asyncio
import websockets
import json
import socket
import threading
import time
from collections import deque
from datetime import datetime, timedelta
from flask import Flask, jsonify, request, Response
from flask_cors import CORS
import queue
import logging

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class XrayRDataCollector:
    """XrayR数据收集器 - 连接TCP接口收集数据"""
    
    def __init__(self, host='127.0.0.1', port=9999, max_records=10000):
        self.host = host
        self.port = port
        self.max_records = max_records
        self.records = deque(maxlen=max_records)  # 限制内存使用
        self.websocket_clients = set()
        self.running = False
        self.stats = {
            'total_records': 0,
            'users': {},
            'domains': {},
            'last_update': None
        }
        
    def start(self):
        """启动数据收集器"""
        self.running = True
        thread = threading.Thread(target=self._collect_data, daemon=True)
        thread.start()
        logger.info(f"数据收集器已启动，连接到 {self.host}:{self.port}")
        
    def _collect_data(self):
        """收集数据的主循环"""
        while self.running:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.connect((self.host, self.port))
                logger.info("已连接到XrayR实时推送服务")
                
                buffer = ""
                while self.running:
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
                                    self._process_record(message['data'])
                            except json.JSONDecodeError:
                                pass
                                
            except Exception as e:
                logger.error(f"连接错误: {e}")
                time.sleep(5)  # 5秒后重连
                
    def _process_record(self, data):
        """处理单条记录"""
        # 添加时间戳
        data['received_at'] = datetime.now().isoformat()
        
        # 存储记录
        self.records.append(data)
        
        # 更新统计
        self.stats['total_records'] += 1
        self.stats['last_update'] = data['received_at']
        
        # 用户统计
        user_key = f"{data.get('email', '')}_{data.get('user_id', '')}"
        self.stats['users'][user_key] = self.stats['users'].get(user_key, 0) + 1
        
        # 域名统计
        domain = data.get('domain', '')
        self.stats['domains'][domain] = self.stats['domains'].get(domain, 0) + 1
        
        # 推送给WebSocket客户端
        self._broadcast_to_websockets(data)
        
    def _broadcast_to_websockets(self, data):
        """广播数据给所有WebSocket客户端"""
        if self.websocket_clients:
            message = json.dumps(data, ensure_ascii=False)
            disconnected = set()
            
            for client in self.websocket_clients:
                try:
                    asyncio.run_coroutine_threadsafe(
                        client.send(message), 
                        asyncio.get_event_loop()
                    )
                except:
                    disconnected.add(client)
            
            # 清理断开的客户端
            self.websocket_clients -= disconnected
    
    def get_latest_records(self, limit=100, filter_user=None, filter_domain=None, since=None):
        """获取最新记录"""
        records = list(self.records)
        
        # 应用过滤器
        if filter_user:
            records = [r for r in records if filter_user in r.get('email', '')]
            
        if filter_domain:
            records = [r for r in records if filter_domain in r.get('domain', '')]
            
        if since:
            try:
                since_dt = datetime.fromisoformat(since)
                records = [r for r in records 
                          if datetime.fromisoformat(r['received_at']) > since_dt]
            except ValueError:
                pass
        
        # 返回最新的记录
        return records[-limit:] if limit else records
    
    def get_stats(self):
        """获取统计信息"""
        return {
            'total_records': self.stats['total_records'],
            'records_in_memory': len(self.records),
            'websocket_clients': len(self.websocket_clients),
            'last_update': self.stats['last_update'],
            'top_users': sorted(self.stats['users'].items(), 
                               key=lambda x: x[1], reverse=True)[:10],
            'top_domains': sorted(self.stats['domains'].items(), 
                                 key=lambda x: x[1], reverse=True)[:20]
        }

# 创建全局数据收集器
collector = XrayRDataCollector()

# 创建Flask应用
app = Flask(__name__)
CORS(app)  # 启用跨域支持

@app.route('/api/records', methods=['GET'])
def get_records():
    """获取访问记录"""
    limit = request.args.get('limit', 100, type=int)
    filter_user = request.args.get('user')
    filter_domain = request.args.get('domain')
    since = request.args.get('since')
    
    records = collector.get_latest_records(
        limit=limit,
        filter_user=filter_user,
        filter_domain=filter_domain,
        since=since
    )
    
    return jsonify({
        'status': 'success',
        'count': len(records),
        'data': records
    })

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """获取统计信息"""
    stats = collector.get_stats()
    return jsonify({
        'status': 'success',
        'data': stats
    })

@app.route('/api/stream', methods=['GET'])
def stream_records():
    """SSE流式接口"""
    def generate():
        # 发送历史数据
        records = collector.get_latest_records(limit=10)
        for record in records:
            yield f"data: {json.dumps(record, ensure_ascii=False)}\n\n"
        
        # 实时数据需要通过其他方式实现
        # 这里只是示例
        while True:
            time.sleep(1)
            yield f"data: {json.dumps({'ping': datetime.now().isoformat()})}\n\n"
    
    return Response(generate(), mimetype='text/plain')

@app.route('/api/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'healthy',
        'service': 'XrayR URL Logger API',
        'timestamp': datetime.now().isoformat(),
        'collector_running': collector.running
    })

@app.route('/', methods=['GET'])
def index():
    """API文档首页"""
    return jsonify({
        'service': 'XrayR URL Logger HTTP API',
        'version': '1.0.0',
        'endpoints': {
            '/api/records': 'GET - 获取访问记录',
            '/api/stats': 'GET - 获取统计信息',
            '/api/stream': 'GET - SSE流式接口',
            '/api/health': 'GET - 健康检查',
            '/ws': 'WebSocket - 实时数据推送'
        },
        'parameters': {
            '/api/records': {
                'limit': 'int - 返回记录数量限制（默认100）',
                'user': 'string - 过滤用户邮箱包含的文本',
                'domain': 'string - 过滤域名包含的文本',
                'since': 'string - ISO格式时间，获取此时间之后的记录'
            }
        },
        'websocket_url': 'ws://localhost:8080/ws'
    })

# WebSocket处理器
async def websocket_handler(websocket, path):
    """WebSocket处理器"""
    if path == '/ws':
        collector.websocket_clients.add(websocket)
        logger.info(f"WebSocket客户端连接: {websocket.remote_address}")
        
        try:
            # 发送欢迎消息
            await websocket.send(json.dumps({
                'type': 'welcome',
                'message': 'XrayR URL Logger WebSocket连接成功'
            }))
            
            # 发送最近的记录
            recent_records = collector.get_latest_records(limit=5)
            for record in recent_records:
                await websocket.send(json.dumps(record, ensure_ascii=False))
            
            # 保持连接
            await websocket.wait_closed()
            
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            collector.websocket_clients.discard(websocket)
            logger.info(f"WebSocket客户端断开: {websocket.remote_address}")

def start_websocket_server():
    """启动WebSocket服务器"""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    start_server = websockets.serve(websocket_handler, "0.0.0.0", 8081)
    logger.info("WebSocket服务器启动在端口 8081")
    
    loop.run_until_complete(start_server)
    loop.run_forever()

if __name__ == '__main__':
    # 启动数据收集器
    collector.start()
    
    # 启动WebSocket服务器
    ws_thread = threading.Thread(target=start_websocket_server, daemon=True)
    ws_thread.start()
    
    # 启动HTTP API服务器
    logger.info("HTTP API服务器启动在端口 8080")
    app.run(host='0.0.0.0', port=8080, debug=False) 