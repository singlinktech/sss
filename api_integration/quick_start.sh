#!/bin/bash
# XrayR URL Logger API 快速开始脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "============================================="
echo "  🚀 XrayR URL Logger API 快速开始"
echo "============================================="
echo

# 检查XrayR服务状态
check_xrayr_status() {
    echo -e "${BLUE}[1/5]${NC} 检查XrayR服务状态..."
    
    if systemctl is-active --quiet xrayr; then
        echo -e "${GREEN}✅ XrayR服务正在运行${NC}"
    else
        echo -e "${RED}❌ XrayR服务未运行${NC}"
        echo "   请先启动XrayR: systemctl start xrayr"
        exit 1
    fi
}

# 检查端口是否开放
check_port_status() {
    echo -e "${BLUE}[2/5]${NC} 检查端口状态..."
    
    if netstat -tlnp | grep -q ":9999"; then
        echo -e "${GREEN}✅ 端口9999已开放${NC}"
    else
        echo -e "${RED}❌ 端口9999未开放${NC}"
        echo "   请检查XrayR配置中的RealtimeAddr设置"
        exit 1
    fi
}

# 测试TCP连接
test_tcp_connection() {
    echo -e "${BLUE}[3/5]${NC} 测试TCP连接..."
    
    python3 << 'EOF'
import socket
import json
import sys
import time

def test_tcp():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect(('127.0.0.1', 9999))
        
        print("✅ TCP连接成功")
        
        # 等待数据
        sock.settimeout(10)
        data = sock.recv(1024).decode('utf-8')
        
        if data:
            print("✅ 收到数据:", data[:100] + "..." if len(data) > 100 else data)
        else:
            print("⚠️  连接成功但暂时没有数据")
        
        sock.close()
        return True
        
    except socket.timeout:
        print("⚠️  连接超时，可能暂时没有数据")
        return True
    except Exception as e:
        print(f"❌ TCP连接失败: {e}")
        return False

if not test_tcp():
    sys.exit(1)
EOF
}

# 创建测试客户端
create_test_client() {
    echo -e "${BLUE}[4/5]${NC} 创建测试客户端..."
    
    cat > test_api_client.py << 'EOF'
#!/usr/bin/env python3
import socket
import json
import time
from datetime import datetime

def test_realtime_api():
    print("🔗 连接到XrayR实时API...")
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect(('127.0.0.1', 9999))
        
        print("✅ 连接成功，等待数据...")
        print("=" * 50)
        
        buffer = ""
        count = 0
        
        while count < 10:  # 只接收前10条数据作为测试
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
                            data = message['data']
                            print(f"📊 [{datetime.now().strftime('%H:%M:%S')}] "
                                  f"用户{data.get('user_id', 'N/A')} 访问 {data.get('domain', 'N/A')} "
                                  f"(IP: {data.get('source_ip', 'N/A')})")
                            count += 1
                    except json.JSONDecodeError:
                        pass
        
        sock.close()
        print("=" * 50)
        print(f"✅ 测试完成，共接收到 {count} 条数据")
        
    except Exception as e:
        print(f"❌ 连接失败: {e}")
        print("请检查:")
        print("1. XrayR服务是否正在运行")
        print("2. URL记录器是否已启用")
        print("3. 是否有用户正在使用代理")

if __name__ == '__main__':
    test_realtime_api()
EOF
    
    chmod +x test_api_client.py
    echo -e "${GREEN}✅ 测试客户端已创建: test_api_client.py${NC}"
}

# 运行测试
run_test() {
    echo -e "${BLUE}[5/5]${NC} 运行实时数据测试..."
    echo
    echo -e "${YELLOW}提示: 请确保有用户正在使用代理访问网站，否则可能看不到数据${NC}"
    echo -e "${YELLOW}测试将运行10秒钟，或收到10条数据后停止${NC}"
    echo
    
    read -p "按回车键开始测试..." -r
    echo
    
    python3 test_api_client.py
}

# 显示下一步操作
show_next_steps() {
    echo
    echo "🎉 快速开始测试完成！"
    echo
    echo "=== 下一步操作 ==="
    echo "1. 📖 查看完整对接指南: cat API_INTEGRATION_GUIDE.md"
    echo "2. 🔧 部署HTTP API代理: ./deploy_api.sh"
    echo "3. 📊 运行客户端示例: python3 client_examples.py"
    echo "4. 🚀 配置纯实时推送: 编辑config.yml"
    echo
    echo "=== 有用的命令 ==="
    echo "重新测试: ./test_api_client.py"
    echo "检查XrayR: systemctl status xrayr"
    echo "查看日志: journalctl -u xrayr -f"
    echo "检查端口: netstat -tlnp | grep 9999"
    echo
    echo "=== 需要帮助？ ==="
    echo "📧 问题反馈: GitHub Issues"
    echo "📖 详细文档: API_INTEGRATION_GUIDE.md"
    echo "💬 社区讨论: 加入讨论群组"
}

# 主程序
main() {
    check_xrayr_status
    check_port_status
    test_tcp_connection
    create_test_client
    run_test
    show_next_steps
}

# 运行主程序
main "$@" 