#!/usr/bin/env python3
"""
XrayR URL访问实时推送客户端示例

这个示例程序演示如何连接到XrayR的实时推送服务器并接收URL访问数据。

使用方法:
    python3 realtime_client.py [服务器地址] [服务器端口]

默认连接到 127.0.0.1:9999
"""

import socket
import json
import sys
import time
from datetime import datetime

def connect_to_server(host='127.0.0.1', port=9999):
    """连接到XrayR实时推送服务器"""
    try:
        # 创建socket连接
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((host, port))
        print(f"[{datetime.now()}] 成功连接到服务器 {host}:{port}")
        return s
    except Exception as e:
        print(f"连接失败: {e}")
        return None

def receive_data(sock):
    """接收并处理实时推送的数据"""
    buffer = ""
    
    while True:
        try:
            # 接收数据
            data = sock.recv(4096).decode('utf-8')
            if not data:
                print("服务器断开连接")
                break
            
            # 处理数据（按行分割）
            buffer += data
            lines = buffer.split('\n')
            buffer = lines[-1]  # 保留未完成的行
            
            for line in lines[:-1]:
                if line.strip():
                    process_message(line)
                    
        except Exception as e:
            print(f"接收数据错误: {e}")
            break

def process_message(message):
    """处理接收到的消息"""
    try:
        data = json.loads(message)
        msg_type = data.get('type', 'unknown')
        
        if msg_type == 'welcome':
            # 欢迎消息
            print(f"[服务器] {data.get('message', '')}")
            
        elif msg_type == 'heartbeat':
            # 心跳消息
            print(f"[心跳] {data.get('time', '')}")
            
        elif msg_type == 'url_access':
            # URL访问记录
            access_data = data.get('data', {})
            print("\n" + "="*60)
            print(f"[URL访问记录] {access_data.get('request_time', '')}")
            print(f"用户邮箱: {access_data.get('email', '')}")
            print(f"用户ID: {access_data.get('user_id', '')}")
            print(f"源IP: {access_data.get('source_ip', '')}")
            print(f"访问域名: {access_data.get('domain', '')}")
            print(f"完整URL: {access_data.get('full_url', '')}")
            print(f"协议: {access_data.get('protocol', '')}")
            print(f"节点ID: {access_data.get('node_id', '')}")
            print(f"节点标签: {access_data.get('node_tag', '')}")
            print(f"额外信息: {access_data.get('user_info', '')}")
            print("="*60)
            
            # 这里可以添加自己的处理逻辑
            # 例如：保存到数据库、发送告警等
            save_to_database(access_data)
            
    except json.JSONDecodeError as e:
        print(f"JSON解析错误: {e}")
        print(f"原始消息: {message}")

def save_to_database(data):
    """保存数据到数据库（示例）"""
    # 这里可以实现实际的数据库保存逻辑
    # 例如：使用SQLite、MySQL、MongoDB等
    
    # 示例：保存到文件
    with open('url_access_log.jsonl', 'a') as f:
        f.write(json.dumps(data, ensure_ascii=False) + '\n')

def main():
    # 解析命令行参数
    host = '127.0.0.1'
    port = 9999
    
    if len(sys.argv) > 1:
        host = sys.argv[1]
    if len(sys.argv) > 2:
        port = int(sys.argv[2])
    
    print(f"XrayR URL访问实时推送客户端")
    print(f"连接到 {host}:{port}")
    print("-" * 60)
    
    # 自动重连逻辑
    while True:
        sock = connect_to_server(host, port)
        if sock:
            try:
                receive_data(sock)
            finally:
                sock.close()
        
        print(f"\n等待5秒后重新连接...")
        time.sleep(5)

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n程序已退出") 