#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XrayR URL Logger JSON监控器 - 纯JSON输出
仅输出url_access类型的JSON数据，适用于脚本处理和API集成
"""

import socket
import json
import sys
import argparse
import signal

class JSONMonitor:
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
            self.socket.settimeout(60)
            return True
        except Exception as e:
            print(f"连接失败: {e}", file=sys.stderr)
            return False
    
    def start_monitoring(self, filter_user=None, filter_domain=None):
        """开始监控并输出JSON"""
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
                buffer = lines[-1]
                
                for line in lines[:-1]:
                    if line.strip():
                        try:
                            message = json.loads(line.strip())
                            self.handle_message(message, filter_user, filter_domain)
                        except json.JSONDecodeError:
                            pass
                            
        except Exception as e:
            print(f"监控错误: {e}", file=sys.stderr)
        finally:
            if self.socket:
                self.socket.close()
    
    def handle_message(self, message, filter_user=None, filter_domain=None):
        """处理消息，只输出url_access类型的JSON"""
        if message.get('type') == 'url_access':
            data = message.get('data', {})
            
            # 应用过滤器
            if filter_user and filter_user not in data.get('email', ''):
                return
            if filter_domain and filter_domain not in data.get('domain', ''):
                return
            
            # 输出完整的JSON消息
            print(json.dumps(message, ensure_ascii=False))
            sys.stdout.flush()

def signal_handler(signum, frame):
    """信号处理器"""
    sys.exit(0)

def main():
    parser = argparse.ArgumentParser(description='XrayR URL Logger JSON监控器')
    parser.add_argument('--host', default='127.0.0.1', help='服务器地址')
    parser.add_argument('--port', type=int, default=9999, help='服务器端口')
    parser.add_argument('--filter-user', help='过滤特定用户')
    parser.add_argument('--filter-domain', help='过滤特定域名')
    
    args = parser.parse_args()
    
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    monitor = JSONMonitor(host=args.host, port=args.port)
    
    try:
        monitor.start_monitoring(
            filter_user=args.filter_user,
            filter_domain=args.filter_domain
        )
    except KeyboardInterrupt:
        pass
    except Exception as e:
        print(f"程序错误: {e}", file=sys.stderr)

if __name__ == "__main__":
    main() 