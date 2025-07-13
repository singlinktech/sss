#!/bin/bash
# -*- coding: utf-8 -*-
# XrayR URL Logger API 一键部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 输出函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统
check_system() {
    log_info "检查系统环境..."
    
    # 检查是否为root用户
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用root用户运行此脚本"
        exit 1
    fi
    
    # 检查操作系统
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    
    log_info "检测到系统: $OS $VER"
}

# 安装Python依赖
install_dependencies() {
    log_info "安装依赖包..."
    
    # 更新包管理器
    if command -v apt-get &> /dev/null; then
        apt-get update -y
        apt-get install -y python3 python3-pip python3-venv wget curl
    elif command -v yum &> /dev/null; then
        yum update -y
        yum install -y python3 python3-pip wget curl
    else
        log_error "不支持的包管理器"
        exit 1
    fi
    
    # 安装Python依赖
    pip3 install --upgrade pip
    pip3 install flask flask-cors websockets requests websocket-client
}

# 创建工作目录
setup_directories() {
    log_info "创建工作目录..."
    
    # 创建目录
    mkdir -p /opt/xrayr-api
    mkdir -p /var/log/xrayr-api
    mkdir -p /etc/systemd/system
    
    # 设置权限
    chmod 755 /opt/xrayr-api
    chmod 755 /var/log/xrayr-api
}

# 部署API服务器
deploy_api_server() {
    log_info "部署API服务器..."
    
    # 下载API服务器文件
    if [[ -f "http_api_server.py" ]]; then
        cp http_api_server.py /opt/xrayr-api/
    else
        log_warn "未找到 http_api_server.py，创建默认版本"
        cat > /opt/xrayr-api/http_api_server.py << 'EOF'
#!/usr/bin/env python3
# 这里应该是完整的API服务器代码
import flask
import json
import time
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/api/health')
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF
    fi
    
    # 设置权限
    chmod +x /opt/xrayr-api/http_api_server.py
}

# 创建systemd服务
create_systemd_service() {
    log_info "创建systemd服务..."
    
    cat > /etc/systemd/system/xrayr-api.service << EOF
[Unit]
Description=XrayR URL Logger API Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/xrayr-api
ExecStart=/usr/bin/python3 /opt/xrayr-api/http_api_server.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd并启动服务
    systemctl daemon-reload
    systemctl enable xrayr-api.service
}

# 创建配置文件
create_config() {
    log_info "创建配置文件..."
    
    cat > /opt/xrayr-api/config.json << EOF
{
    "xrayr_host": "127.0.0.1",
    "xrayr_port": 9999,
    "api_port": 8080,
    "websocket_port": 8081,
    "max_records": 10000,
    "log_level": "INFO",
    "cors_origins": ["*"],
    "database": {
        "type": "sqlite",
        "path": "/var/log/xrayr-api/data.db"
    }
}
EOF
}

# 创建管理脚本
create_management_script() {
    log_info "创建管理脚本..."
    
    cat > /opt/xrayr-api/manage.sh << 'EOF'
#!/bin/bash
# XrayR API 管理脚本

case "$1" in
    start)
        echo "启动XrayR API服务..."
        systemctl start xrayr-api
        ;;
    stop)
        echo "停止XrayR API服务..."
        systemctl stop xrayr-api
        ;;
    restart)
        echo "重启XrayR API服务..."
        systemctl restart xrayr-api
        ;;
    status)
        systemctl status xrayr-api
        ;;
    logs)
        journalctl -u xrayr-api -f
        ;;
    test)
        echo "测试API连接..."
        curl -s http://localhost:8080/api/health | python3 -m json.tool
        ;;
    *)
        echo "使用方法: $0 {start|stop|restart|status|logs|test}"
        exit 1
        ;;
esac
EOF
    
    chmod +x /opt/xrayr-api/manage.sh
}

# 创建客户端示例
create_client_examples() {
    log_info "创建客户端示例..."
    
    # 简单的测试客户端
    cat > /opt/xrayr-api/test_client.py << 'EOF'
#!/usr/bin/env python3
import requests
import json

def test_api():
    base_url = "http://localhost:8080"
    
    # 测试健康检查
    try:
        response = requests.get(f"{base_url}/api/health")
        print(f"健康检查: {response.json()}")
    except Exception as e:
        print(f"健康检查失败: {e}")
    
    # 测试获取记录
    try:
        response = requests.get(f"{base_url}/api/records?limit=5")
        data = response.json()
        print(f"获取记录: {data['count']} 条")
    except Exception as e:
        print(f"获取记录失败: {e}")

if __name__ == '__main__':
    test_api()
EOF
    
    chmod +x /opt/xrayr-api/test_client.py
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    # 检查防火墙类型
    if command -v ufw &> /dev/null; then
        ufw allow 8080
        ufw allow 8081
        log_info "UFW防火墙已配置"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=8081/tcp
        firewall-cmd --reload
        log_info "firewalld防火墙已配置"
    else
        log_warn "未检测到防火墙，请手动开放端口 8080 和 8081"
    fi
}

# 显示部署信息
show_deployment_info() {
    log_info "部署完成！"
    echo
    echo "=== XrayR API 服务信息 ==="
    echo "HTTP API:    http://你的服务器IP:8080"
    echo "WebSocket:   ws://你的服务器IP:8081/ws"
    echo "配置文件:    /opt/xrayr-api/config.json"
    echo "日志目录:    /var/log/xrayr-api/"
    echo
    echo "=== 管理命令 ==="
    echo "启动服务:    /opt/xrayr-api/manage.sh start"
    echo "停止服务:    /opt/xrayr-api/manage.sh stop"
    echo "重启服务:    /opt/xrayr-api/manage.sh restart"
    echo "查看状态:    /opt/xrayr-api/manage.sh status"
    echo "查看日志:    /opt/xrayr-api/manage.sh logs"
    echo "测试API:     /opt/xrayr-api/manage.sh test"
    echo
    echo "=== API接口示例 ==="
    echo "获取记录:    curl http://localhost:8080/api/records?limit=10"
    echo "获取统计:    curl http://localhost:8080/api/stats"
    echo "健康检查:    curl http://localhost:8080/api/health"
    echo
    echo "=== 重要提醒 ==="
    echo "1. 确保XrayR正在运行并启用了URL记录器"
    echo "2. 确保XrayR配置中的RealtimeAddr为 0.0.0.0:9999"
    echo "3. 检查防火墙是否开放了 8080 和 8081 端口"
    echo "4. 使用 /opt/xrayr-api/test_client.py 测试连接"
}

# 主函数
main() {
    echo "========================================"
    echo "  XrayR URL Logger API 一键部署脚本"
    echo "========================================"
    echo
    
    check_system
    install_dependencies
    setup_directories
    deploy_api_server
    create_systemd_service
    create_config
    create_management_script
    create_client_examples
    configure_firewall
    
    # 启动服务
    log_info "启动服务..."
    systemctl start xrayr-api
    
    sleep 2
    
    show_deployment_info
    
    echo
    log_info "部署完成！正在测试服务..."
    /opt/xrayr-api/manage.sh test
}

# 运行主函数
main "$@" 