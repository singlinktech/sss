#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XrayR URL Logger 实时监控客户端
GitHub: https://github.com/singlinktech/sss
"""

import socket
import json
import time
import sys
import threading
from datetime import datetime
import argparse
import os
import signal

class XrayRMonitor:
    def __init__(self, host='127.0.0.1', port=9999, debug=False):
        self.host = host
        self.port = port
        self.debug = debug
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
    
    def start_monitoring(self, save_to_file=None, filter_user=None, filter_domain=None):
        """开始监控"""
        if not self.connect():
            return
        
        self.running = True
        buffer = ""
        
        # 文件写入设置
        file_handle = None
        if save_to_file:
            try:
                file_handle = open(save_to_file, 'a', encoding='utf-8')
                print(f"📁 监控数据将保存到: {save_to_file}")
            except Exception as e:
                print(f"⚠️ 无法打开文件 {save_to_file}: {e}")
        
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
                            self.handle_message(message, file_handle, filter_user, filter_domain)
                        except json.JSONDecodeError as e:
                            if self.debug:
                                print(f"⚠️ JSON解析错误: {e}")
                            
        except socket.timeout:
            print("⏰ 连接超时，尝试重连...")
            self.reconnect()
        except Exception as e:
            print(f"❌ 监控错误: {e}")
        finally:
            if file_handle:
                file_handle.close()
            self.disconnect()
    
    def reconnect(self):
        """重新连接"""
        print("🔄 正在重新连接...")
        self.disconnect()
        time.sleep(3)
        self.start_monitoring()
    
    def handle_message(self, message, file_handle=None, filter_user=None, filter_domain=None):
        """处理接收到的消息"""
        msg_type = message.get('type', 'unknown')
        
        if msg_type == 'welcome':
            print(f"🎉 {message.get('message', '')}")
            
        elif msg_type == 'heartbeat':
            if self.debug:
                print(f"💓 心跳: {message.get('time', '')}")
            
        elif msg_type == 'url_access':
            data = message.get('data', {})
            
            # 应用过滤器
            if filter_user and filter_user not in data.get('email', ''):
                return
            if filter_domain and filter_domain not in data.get('domain', ''):
                return
            
            self.display_url_access(data)
            
            # 保存到文件
            if file_handle:
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                record = f"[{timestamp}] {json.dumps(data, ensure_ascii=False)}\n"
                file_handle.write(record)
                file_handle.flush()
        
        else:
            if self.debug:
                print(f"❓ 未知消息类型: {msg_type}")
    
    def display_url_access(self, data):
        """格式化显示URL访问记录"""
        print("\n" + "="*60)
        print(f"🌐 URL访问记录")
        print("="*60)
        print(f"⏰ 时间: {data.get('request_time', 'N/A')}")
        print(f"👤 用户: {data.get('email', 'N/A')} (ID: {data.get('user_id', 'N/A')})")
        print(f"🎯 访问: {data.get('domain', 'N/A')}")
        print(f"📍 来源: {data.get('source_ip', 'N/A')}")
        print(f"🔗 协议: {data.get('protocol', 'N/A')}")
        print(f"🏷️ 节点: {data.get('node_tag', 'N/A')} (ID: {data.get('node_id', 'N/A')})")
        if data.get('full_url'):
            print(f"🌍 完整URL: {data.get('full_url', 'N/A')}")
        if data.get('user_info'):
            print(f"ℹ️ 用户信息: {data.get('user_info', 'N/A')}")
        print("="*60)

def signal_handler(signum, frame):
    """信号处理器"""
    print("\n👋 收到退出信号，正在关闭...")
    sys.exit(0)

def main():
    """主程序"""
    parser = argparse.ArgumentParser(description='XrayR URL Logger 实时监控客户端')
    parser.add_argument('--host', default='127.0.0.1', help='服务器地址 (默认: 127.0.0.1)')
    parser.add_argument('--port', type=int, default=9999, help='服务器端口 (默认: 9999)')
    parser.add_argument('--debug', action='store_true', help='启用调试模式')
    parser.add_argument('--save', help='保存监控数据到文件')
    parser.add_argument('--filter-user', help='过滤特定用户 (邮箱包含)')
    parser.add_argument('--filter-domain', help='过滤特定域名 (域名包含)')
    
    args = parser.parse_args()
    
    # 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    print("XrayR URL Logger 实时监控客户端")
    print(f"连接地址: {args.host}:{args.port}")
    if args.filter_user:
        print(f"用户过滤: {args.filter_user}")
    if args.filter_domain:
        print(f"域名过滤: {args.filter_domain}")
    if args.save:
        print(f"保存文件: {args.save}")
    print("按 Ctrl+C 退出")
    print("-" * 50)
    
    monitor = XrayRMonitor(host=args.host, port=args.port, debug=args.debug)
    
    try:
        monitor.start_monitoring(
            save_to_file=args.save,
            filter_user=args.filter_user,
            filter_domain=args.filter_domain
        )
    except KeyboardInterrupt:
        print("\n👋 用户终止程序")
    except Exception as e:
        print(f"❌ 程序错误: {e}")
    finally:
        monitor.disconnect()

if __name__ == "__main__":
    main() 