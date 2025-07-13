#!/bin/bash

# ======================================
# XrayR URL Logger 一键安装脚本 
# 完整版本 - 集成所有实时数据API功能
# ======================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 版本信息
VERSION="v2.0.0"
REPO_URL="https://github.com/singlinktech/sss"
DOWNLOAD_URL="https://github.com/singlinktech/sss/releases/latest/download"

# 显示欢迎信息
show_welcome() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║  🚀 XrayR URL Logger - 实时数据API版本                          ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║  ✨ 特性:                                                        ║${NC}"
    echo -e "${CYAN}║    📊 实时数据推送 (TCP/HTTP/WebSocket)                         ║${NC}"
    echo -e "${CYAN}║    💾 零文件存储模式 (节省硬盘空间)                             ║${NC}"
    echo -e "${CYAN}║    🌐 多协议API接口                                             ║${NC}"
    echo -e "${CYAN}║    🔧 一键安装，自动配置                                        ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║  安装完成后，您将获得：                                          ║${NC}"
    echo -e "${CYAN}║    • TCP实时推送端口 9999                                        ║${NC}"
    echo -e "${CYAN}║    • HTTP API代理服务 (可选)                                     ║${NC}"
    echo -e "${CYAN}║    • WebSocket实时推送 (可选)                                    ║${NC}"
    echo -e "${CYAN}║    • 完整的客户端示例                                            ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 检查系统环境
check_system() {
    log_step "检查系统环境..."
    
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then 
        log_error "请使用root用户运行此脚本"
        echo "使用方法: sudo bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/ONE_CLICK_INSTALL.sh)"
        exit 1
    fi
    
    # 检测系统架构
    arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        *)
            log_error "不支持的架构: $arch (仅支持 x86_64 和 aarch64)"
            exit 1
            ;;
    esac
    
    # 检测操作系统
    if [ -f /etc/redhat-release ]; then
        OS="centos"
        PKG_MANAGER="yum"
    elif grep -qi "debian" /etc/os-release; then
        OS="debian"
        PKG_MANAGER="apt"
    elif grep -qi "ubuntu" /etc/os-release; then
        OS="ubuntu"
        PKG_MANAGER="apt"
    else
        OS="linux"
        PKG_MANAGER="unknown"
    fi
    
    log_success "系统检测完成: $OS ($ARCH)"
}

# 安装依赖
install_dependencies() {
    log_step "安装必要依赖..."
    
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt-get update -y >/dev/null 2>&1
        apt-get install -y wget curl systemd python3 python3-pip unzip >/dev/null 2>&1
    elif [ "$PKG_MANAGER" = "yum" ]; then
        yum update -y >/dev/null 2>&1
        yum install -y wget curl systemd python3 python3-pip unzip >/dev/null 2>&1
    else
        log_warn "未知的包管理器，请手动安装: wget curl systemd python3"
    fi
    
    log_success "依赖安装完成"
}

# 备份现有配置
backup_existing() {
    log_step "备份现有配置..."
    
    # 停止现有服务
    systemctl stop xrayr 2>/dev/null || true
    systemctl stop XrayR 2>/dev/null || true
    
    # 备份配置文件
    if [ -f "/etc/XrayR/config.yml" ]; then
        backup_file="/etc/XrayR/config.yml.backup.$(date +%Y%m%d_%H%M%S)"
        cp "/etc/XrayR/config.yml" "$backup_file"
        log_info "配置文件已备份到: $backup_file"
    fi
    
    log_success "备份完成"
}

# 下载并安装XrayR
install_xrayr() {
    log_step "下载并安装XrayR..."
    
    # 创建必要目录
    mkdir -p /usr/local/bin
    mkdir -p /etc/XrayR
    mkdir -p /var/log/xrayr
    mkdir -p /opt/xrayr-api
    
    # 下载预编译二进制文件
    BINARY_NAME="xrayr-linux-${ARCH}"
    DOWNLOAD_FILE="/tmp/${BINARY_NAME}"
    
    log_info "下载二进制文件: ${BINARY_NAME}"
    if ! wget -q --show-progress -O "$DOWNLOAD_FILE" "${DOWNLOAD_URL}/${BINARY_NAME}"; then
        log_error "下载失败！"
        echo "可能的原因："
        echo "1. 网络连接问题"
        echo "2. GitHub访问受限"
        echo "3. 预编译版本尚未发布"
        echo ""
        echo "请访问 ${REPO_URL}/releases 查看可用版本"
        exit 1
    fi
    
    # 检查下载的文件
    if [ ! -f "$DOWNLOAD_FILE" ] || [ ! -s "$DOWNLOAD_FILE" ]; then
        log_error "下载的文件无效"
        exit 1
    fi
    
    # 安装二进制文件
    cp "$DOWNLOAD_FILE" /usr/local/bin/xrayr
    chmod +x /usr/local/bin/xrayr
    
    # 创建软链接
    ln -sf /usr/local/bin/xrayr /usr/bin/xrayr
    ln -sf /usr/local/bin/xrayr /usr/bin/XrayR
    
    # 验证二进制文件
    if /usr/local/bin/xrayr --help >/dev/null 2>&1; then
        log_info "二进制文件验证成功"
    else
        log_warn "二进制文件可能有问题，但已安装"
    fi
    
    # 清理临时文件
    rm -f "$DOWNLOAD_FILE"
    
    log_success "XrayR安装完成"
}

# 创建默认配置文件
create_config() {
    log_step "创建默认配置文件..."
    
    cat > /etc/XrayR/config.yml << EOF
# XrayR 配置文件 - 实时数据API版本
# 自动生成于: $(date '+%Y-%m-%d %H:%M:%S')

# 日志配置
Log:
  Level: info                    # 日志级别: debug, info, warning, error
  AccessPath: ""                 # 留空以节省空间
  ErrorPath: "/var/log/xrayr/error.log"

# 连接配置
ConnectionConfig:
  Handshake: 4
  ConnIdle: 30
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64

# 节点配置 (请根据您的面板修改)
Nodes:
  - PanelType: "NewV2board"      # 面板类型: NewV2board, V2board, SSPanel, etc.
    ApiConfig:
      ApiHost: "https://your-panel.com"    # 🔥 请修改为您的面板地址
      ApiKey: "your-api-key"               # 🔥 请修改为您的API密钥
      NodeID: 1                            # 🔥 请修改为您的节点ID
      NodeType: Shadowsocks                # 节点类型: V2ray, Shadowsocks, Trojan
      Timeout: 30
      EnableVless: false
      EnableXTLS: false
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath: ""
      
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriod: 60
      EnableDNS: false
      DNSType: AsIs
      EnableProxyProtocol: false
      
      # 自动限速配置
      AutoSpeedLimitConfig:
        Limit: 0
        WarnTimes: 0
        LimitSpeed: 0
        LimitDuration: 0
        
      # 全局设备限制配置
      GlobalDeviceLimitConfig:
        Enable: false
        RedisNetwork: tcp
        RedisAddr: "127.0.0.1:6379"
        RedisPassword: ""
        RedisDB: 0
        Timeout: 5
        Expiry: 60
      
      # 🚀 URL记录器配置 - 实时数据API核心功能
      URLLoggerConfig:
        Enable: true                          # ✅ 启用URL记录器
        LogPath: ""                           # 🔥 留空 = 纯实时模式，不保存文件
        MaxFileSize: 0                        # 🔥 0 = 不保存文件，节省空间
        MaxFileCount: 0                       # 🔥 0 = 不保存文件
        FlushInterval: 1                      # 1秒立即推送，最佳实时性
        EnableDomainLog: true                 # 启用域名记录
        EnableFullURL: true                   # 🚀 启用完整URL记录
        
        # 🌐 实时推送配置 (核心功能)
        EnableRealtime: true                  # 🔥 启用实时推送
        RealtimeAddr: "0.0.0.0:9999"         # 🔥 监听所有网络接口，端口9999
        
        # 🔧 域名过滤配置
        ExcludeDomains:                       # 排除不需要记录的域名
          - "localhost"
          - "127.0.0.1"
          - "apple.com"                       # 排除苹果系统请求
          - "icloud.com"
          - "microsoft.com"                   # 排除微软系统请求
          - "windows.com"
          - "ubuntu.com"                      # 排除系统更新请求
          - "debian.org"
          - "google.com/generate_204"         # 排除网络检测请求
          - "gstatic.com"
          - "googleapis.com"
          
        # IncludeDomains:                     # 如果只想记录特定域名，取消注释并配置
        #   - "example.com"
        #   - "target-site.com"
        
        # 🛡️ 恶意域名检测配置
        EnableMaliciousDetection: true        # 启用恶意域名检测
        MaliciousDomains:                     # 恶意域名列表
          - "malicious-site.com"
          - "phishing-site.com"
          - "suspicious-domain.net"
EOF
    
    log_success "默认配置文件已创建"
    log_warn "⚠️  重要提醒: 请编辑 /etc/XrayR/config.yml 修改面板配置"
    echo "   需要修改的字段:"
    echo "   - ApiHost: 您的面板地址"
    echo "   - ApiKey: 您的API密钥"
    echo "   - NodeID: 您的节点ID"
    echo "   - NodeType: 节点类型"
}

# 创建systemd服务
create_systemd_service() {
    log_step "创建systemd服务..."
    
    cat > /etc/systemd/system/xrayr.service << 'EOF'
[Unit]
Description=XrayR URL Logger Service
Documentation=https://github.com/singlinktech/sss
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
NoNewPrivileges=true
ExecStart=/usr/local/bin/xrayr -c /etc/XrayR/config.yml
Restart=on-failure
RestartPreventExitStatus=1
RestartSec=5
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd配置
    systemctl daemon-reload
    systemctl enable xrayr
    
    log_success "systemd服务已创建并启用"
}

# 安装API代理工具
install_api_tools() {
    log_step "安装API代理工具..."
    
    # 安装Python依赖
    pip3 install --quiet flask flask-cors websockets requests websocket-client >/dev/null 2>&1 || {
        log_warn "Python依赖安装失败，API代理功能可能不可用"
        return
    }
    
    # 下载API代理服务器
    wget -q -O /opt/xrayr-api/http_api_server.py "https://raw.githubusercontent.com/singlinktech/sss/main/api_integration/http_api_server.py" || {
        log_warn "API代理服务器下载失败"
        return
    }
    
    # 下载客户端示例
    wget -q -O /opt/xrayr-api/client_examples.py "https://raw.githubusercontent.com/singlinktech/sss/main/api_integration/client_examples.py" || {
        log_warn "客户端示例下载失败"
    }
    
    # 创建API代理服务
    cat > /etc/systemd/system/xrayr-api.service << 'EOF'
[Unit]
Description=XrayR API Proxy Server
After=network.target xrayr.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/xrayr-api
ExecStart=/usr/bin/python3 /opt/xrayr-api/http_api_server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # 创建管理脚本
    cat > /opt/xrayr-api/manage.sh << 'EOF'
#!/bin/bash
# XrayR API 管理脚本

case "$1" in
    start)
        echo "启动XrayR API代理服务..."
        systemctl start xrayr-api
        ;;
    stop)
        echo "停止XrayR API代理服务..."
        systemctl stop xrayr-api
        ;;
    restart)
        echo "重启XrayR API代理服务..."
        systemctl restart xrayr-api
        ;;
    status)
        systemctl status xrayr-api
        ;;
    logs)
        journalctl -u xrayr-api -f
        ;;
    enable)
        echo "启用XrayR API代理服务..."
        systemctl enable xrayr-api
        systemctl start xrayr-api
        ;;
    disable)
        echo "禁用XrayR API代理服务..."
        systemctl stop xrayr-api
        systemctl disable xrayr-api
        ;;
    test)
        echo "测试API连接..."
        curl -s http://localhost:8080/api/health | python3 -m json.tool 2>/dev/null || echo "API服务未启动或连接失败"
        ;;
    *)
        echo "XrayR API 管理脚本"
        echo "使用方法: $0 {start|stop|restart|status|logs|enable|disable|test}"
        echo ""
        echo "常用命令:"
        echo "  $0 enable   - 启用并启动API代理服务"
        echo "  $0 status   - 查看服务状态"
        echo "  $0 logs     - 查看实时日志"
        echo "  $0 test     - 测试API连接"
        exit 1
        ;;
esac
EOF
    
    chmod +x /opt/xrayr-api/manage.sh
    
    log_success "API代理工具安装完成"
}

# 创建快速测试脚本
create_test_script() {
    log_step "创建快速测试脚本..."
    
    cat > /usr/local/bin/xrayr-test << 'EOF'
#!/bin/bash
# XrayR 实时数据测试脚本

echo "🚀 XrayR 实时数据测试"
echo "===================="

# 检查XrayR服务状态
echo "1. 检查XrayR服务状态..."
if systemctl is-active --quiet xrayr; then
    echo "   ✅ XrayR服务正在运行"
else
    echo "   ❌ XrayR服务未运行"
    echo "   请运行: systemctl start xrayr"
    exit 1
fi

# 检查端口监听
echo "2. 检查实时推送端口..."
if netstat -tlnp 2>/dev/null | grep -q ":9999"; then
    echo "   ✅ 端口9999已开放"
else
    echo "   ❌ 端口9999未监听"
    echo "   请检查配置文件中的URLLoggerConfig设置"
    exit 1
fi

# 测试TCP连接
echo "3. 测试TCP连接..."
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/9999' 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ TCP连接成功"
else
    echo "   ❌ TCP连接失败"
    exit 1
fi

# 显示实时数据（10秒）
echo "4. 监听实时数据 (10秒)..."
echo "   提示: 请确保有用户使用代理访问网站"
echo "   ===================="

timeout 10 python3 -c "
import socket
import json
import time

try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect(('127.0.0.1', 9999))
    sock.settimeout(1)
    
    buffer = ''
    count = 0
    
    while count < 5:  # 最多显示5条数据
        try:
            data = sock.recv(1024).decode('utf-8')
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
                            print(f'   📊 用户{data.get(\"user_id\", \"N/A\")} 访问 {data.get(\"domain\", \"N/A\")}')
                            count += 1
                    except json.JSONDecodeError:
                        pass
        except socket.timeout:
            time.sleep(0.1)
            continue
    
    sock.close()
    
    if count == 0:
        print('   ⚠️  暂时没有数据，请确保:')
        print('      1. 有用户正在使用代理')
        print('      2. 配置文件正确')
        print('      3. 用户正在访问网站')
    else:
        print(f'   ✅ 成功接收到 {count} 条实时数据')
        
except Exception as e:
    print(f'   ❌ 连接错误: {e}')
"

echo "===================="
echo "✅ 测试完成！"
echo ""
echo "如果看到实时数据，说明配置成功！"
echo "如果没有数据，请检查:"
echo "1. 面板配置是否正确"
echo "2. 是否有用户使用代理"
echo "3. 查看日志: journalctl -u xrayr -f"
EOF
    
    chmod +x /usr/local/bin/xrayr-test
    
    log_success "测试脚本已创建: xrayr-test"
}

# 创建管理脚本
create_management_script() {
    log_step "创建管理脚本..."
    
    cat > /usr/local/bin/xrayr-manage << 'EOF'
#!/bin/bash
# XrayR 管理脚本

show_menu() {
    clear
    echo "🚀 XrayR URL Logger 管理面板"
    echo "=========================="
    echo "1. 启动服务"
    echo "2. 停止服务" 
    echo "3. 重启服务"
    echo "4. 查看状态"
    echo "5. 查看日志"
    echo "6. 测试连接"
    echo "7. 编辑配置"
    echo "8. API代理管理"
    echo "9. 卸载服务"
    echo "0. 退出"
    echo "=========================="
}

case "$1" in
    1|start)
        echo "启动XrayR服务..."
        systemctl start xrayr
        ;;
    2|stop)
        echo "停止XrayR服务..."
        systemctl stop xrayr
        ;;
    3|restart)
        echo "重启XrayR服务..."
        systemctl restart xrayr
        ;;
    4|status)
        systemctl status xrayr
        ;;
    5|logs)
        journalctl -u xrayr -f
        ;;
    6|test)
        xrayr-test
        ;;
    7|config)
        nano /etc/XrayR/config.yml
        ;;
    8|api)
        /opt/xrayr-api/manage.sh
        ;;
    9|uninstall)
        echo "确定要卸载XrayR吗? (y/N)"
        read -r confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            systemctl stop xrayr 2>/dev/null || true
            systemctl disable xrayr 2>/dev/null || true
            rm -f /etc/systemd/system/xrayr.service
            rm -f /usr/local/bin/xrayr
            rm -f /usr/bin/xrayr /usr/bin/XrayR
            rm -rf /etc/XrayR
            rm -f /usr/local/bin/xrayr-test
            rm -f /usr/local/bin/xrayr-manage
            systemctl daemon-reload
            echo "XrayR已卸载"
        fi
        ;;
    0|exit)
        exit 0
        ;;
    "")
        while true; do
            show_menu
            read -p "请选择操作 [0-9]: " choice
            case $choice in
                1) systemctl start xrayr && echo "✅ 服务已启动" ;;
                2) systemctl stop xrayr && echo "✅ 服务已停止" ;;
                3) systemctl restart xrayr && echo "✅ 服务已重启" ;;
                4) systemctl status xrayr ;;
                5) echo "按Ctrl+C退出日志查看"; journalctl -u xrayr -f ;;
                6) xrayr-test ;;
                7) nano /etc/XrayR/config.yml ;;
                8) /opt/xrayr-api/manage.sh ;;
                9) 
                    echo "确定要卸载XrayR吗? (y/N)"
                    read -r confirm
                    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                        systemctl stop xrayr 2>/dev/null || true
                        systemctl disable xrayr 2>/dev/null || true
                        rm -f /etc/systemd/system/xrayr.service
                        rm -f /usr/local/bin/xrayr
                        rm -f /usr/bin/xrayr /usr/bin/XrayR
                        rm -rf /etc/XrayR
                        rm -f /usr/local/bin/xrayr-test
                        rm -f /usr/local/bin/xrayr-manage
                        systemctl daemon-reload
                        echo "✅ XrayR已卸载"
                        exit 0
                    fi
                    ;;
                0) exit 0 ;;
                *) echo "❌ 无效选择，请重新输入" ;;
            esac
            echo ""
            read -p "按回车键继续..." -r
        done
        ;;
    *)
        echo "XrayR 管理脚本"
        echo "使用方法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  start     启动服务"
        echo "  stop      停止服务"
        echo "  restart   重启服务"
        echo "  status    查看状态"
        echo "  logs      查看日志"
        echo "  test      测试连接"
        echo "  config    编辑配置"
        echo "  api       API代理管理"
        echo "  uninstall 卸载服务"
        echo ""
        echo "运行 '$0' 进入交互模式"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/xrayr-manage
    
    log_success "管理脚本已创建: xrayr-manage"
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."
    
    # 检查防火墙类型并开放端口
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 9999/tcp >/dev/null 2>&1
        ufw allow 8080/tcp >/dev/null 2>&1
        ufw allow 8081/tcp >/dev/null 2>&1
        log_info "UFW防火墙已配置"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=9999/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=8080/tcp >/dev/null 2>&1
        firewall-cmd --permanent --add-port=8081/tcp >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
        log_info "firewalld防火墙已配置"
    elif command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport 9999 -j ACCEPT >/dev/null 2>&1
        iptables -I INPUT -p tcp --dport 8080 -j ACCEPT >/dev/null 2>&1
        iptables -I INPUT -p tcp --dport 8081 -j ACCEPT >/dev/null 2>&1
        # 尝试保存iptables规则
        service iptables save >/dev/null 2>&1 || true
        log_info "iptables防火墙已配置"
    else
        log_warn "未检测到防火墙，请手动开放端口: 9999, 8080, 8081"
    fi
    
    log_success "防火墙配置完成"
}

# 显示安装结果
show_result() {
    clear
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                  ║${NC}"
    echo -e "${GREEN}║  🎉 XrayR URL Logger 安装完成！                                 ║${NC}"
    echo -e "${GREEN}║                                                                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${CYAN}📊 服务信息${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "实时推送端口:    ${YELLOW}TCP 9999${NC}"
    echo -e "HTTP API端口:    ${YELLOW}8080${NC} (可选，需手动启用)"
    echo -e "WebSocket端口:   ${YELLOW}8081${NC} (可选，需手动启用)"
    echo -e "配置文件:        ${YELLOW}/etc/XrayR/config.yml${NC}"
    echo -e "日志目录:        ${YELLOW}/var/log/xrayr/${NC}"
    echo
    echo -e "${CYAN}🔧 管理命令${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "管理面板:        ${YELLOW}xrayr-manage${NC}"
    echo -e "快速测试:        ${YELLOW}xrayr-test${NC}"
    echo -e "查看状态:        ${YELLOW}systemctl status xrayr${NC}"
    echo -e "查看日志:        ${YELLOW}journalctl -u xrayr -f${NC}"
    echo -e "编辑配置:        ${YELLOW}nano /etc/XrayR/config.yml${NC}"
    echo -e "API代理管理:     ${YELLOW}/opt/xrayr-api/manage.sh${NC}"
    echo
    echo -e "${CYAN}📡 实时数据API接口${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "TCP直连:         ${YELLOW}telnet $(hostname -I | awk '{print $1}') 9999${NC}"
    echo -e "HTTP API:        ${YELLOW}http://$(hostname -I | awk '{print $1}'):8080/api/health${NC}"
    echo -e "WebSocket:       ${YELLOW}ws://$(hostname -I | awk '{print $1}'):8081/ws${NC}"
    echo
    echo -e "${RED}⚠️  重要提醒${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "1. ${YELLOW}请立即编辑配置文件修改面板信息:${NC}"
    echo -e "   nano /etc/XrayR/config.yml"
    echo -e "2. ${YELLOW}需要修改的字段:${NC}"
    echo -e "   - ApiHost: 您的面板地址"
    echo -e "   - ApiKey: 您的API密钥" 
    echo -e "   - NodeID: 您的节点ID"
    echo -e "   - NodeType: 节点类型"
    echo -e "3. ${YELLOW}修改配置后重启服务:${NC}"
    echo -e "   systemctl restart xrayr"
    echo -e "4. ${YELLOW}运行测试检查配置:${NC}"
    echo -e "   xrayr-test"
    echo
    echo -e "${CYAN}🚀 快速开始${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "1. ${GREEN}编辑配置:${NC} nano /etc/XrayR/config.yml"
    echo -e "2. ${GREEN}启动服务:${NC} systemctl start xrayr" 
    echo -e "3. ${GREEN}测试连接:${NC} xrayr-test"
    echo -e "4. ${GREEN}管理面板:${NC} xrayr-manage"
    echo
    echo -e "${PURPLE}📚 完整文档和示例: https://github.com/singlinktech/sss${NC}"
    echo
}

# 启动服务并测试
start_and_test() {
    log_step "启动服务..."
    
    # 重载systemd配置
    systemctl daemon-reload
    
    # 启动XrayR服务
    systemctl start xrayr
    
    # 等待服务启动
    sleep 5
    
    # 详细检查服务状态
    if systemctl is-active --quiet xrayr; then
        log_success "XrayR服务启动成功"
        
        # 检查端口监听
        sleep 2
        if netstat -tlnp 2>/dev/null | grep -q ":9999"; then
            log_success "实时推送端口9999已开启"
        else
            log_warn "端口9999未监听，可能需要检查配置"
        fi
    else
        log_error "XrayR服务启动失败"
        echo ""
        echo "=== 错误诊断 ==="
        echo "1. 查看详细错误: journalctl -u xrayr --no-pager -l"
        echo "2. 检查配置文件: nano /etc/XrayR/config.yml"
        echo "3. 手动测试启动: /usr/local/bin/xrayr -c /etc/XrayR/config.yml"
        echo ""
        echo "=== 最近的错误日志 ==="
        journalctl -u xrayr --no-pager -l -n 10 || echo "无法获取日志"
    fi
}

# 主安装流程
main() {
    # 显示欢迎信息
    show_welcome
    
    # 用户确认
    echo -e "${YELLOW}按回车键开始安装，或按Ctrl+C取消...${NC}"
    read -r
    
    # 执行安装步骤
    check_system
    install_dependencies
    backup_existing
    install_xrayr
    create_config
    create_systemd_service
    install_api_tools
    create_test_script
    create_management_script
    configure_firewall
    start_and_test
    
    # 显示安装结果
    show_result
}

# 运行主程序
main "$@" 