#!/bin/bash

# ======================================
# XrayR 系统诊断脚本
# 用于排查常见问题
# ======================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}XrayR 系统诊断报告${NC}"
echo -e "${BLUE}时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}======================================${NC}"
echo

# 1. 系统基本信息
echo -e "${YELLOW}[1] 系统基本信息${NC}"
echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "内核版本: $(uname -r)"
echo "架构: $(uname -m)"
echo "当前用户: $(whoami)"
echo

# 2. XrayR服务状态
echo -e "${YELLOW}[2] XrayR服务状态${NC}"
if systemctl is-active --quiet xrayr; then
    echo -e "${GREEN}✅ 服务状态: 运行中${NC}"
    echo "启动时间: $(systemctl show xrayr --property=ActiveEnterTimestamp --value)"
    echo "进程ID: $(systemctl show xrayr --property=MainPID --value)"
else
    echo -e "${RED}❌ 服务状态: 未运行${NC}"
    echo "上次启动: $(systemctl show xrayr --property=ActiveEnterTimestamp --value)"
    echo "退出代码: $(systemctl show xrayr --property=ExecMainStatus --value)"
fi
echo

# 3. 端口监听状态
echo -e "${YELLOW}[3] 端口监听状态${NC}"
if command -v netstat >/dev/null 2>&1; then
    if netstat -tlnp 2>/dev/null | grep -q ":9999"; then
        echo -e "${GREEN}✅ 端口9999: 正在监听${NC}"
        netstat -tlnp | grep ":9999"
    else
        echo -e "${RED}❌ 端口9999: 未监听${NC}"
    fi
else
    if ss -tlnp | grep -q ":9999"; then
        echo -e "${GREEN}✅ 端口9999: 正在监听${NC}"
        ss -tlnp | grep ":9999"
    else
        echo -e "${RED}❌ 端口9999: 未监听${NC}"
    fi
fi
echo

# 4. 配置文件检查
echo -e "${YELLOW}[4] 配置文件检查${NC}"
if [ -f "/etc/XrayR/config.yml" ]; then
    echo -e "${GREEN}✅ 配置文件存在${NC}"
    echo "文件路径: /etc/XrayR/config.yml"
    echo "文件大小: $(wc -l < /etc/XrayR/config.yml) 行"
    echo "修改时间: $(stat -c %y /etc/XrayR/config.yml)"
    
    # 检查关键配置
    if grep -q "URLLoggerConfig:" /etc/XrayR/config.yml; then
        echo -e "${GREEN}✅ 包含URL记录器配置${NC}"
        
        if grep -A 10 "URLLoggerConfig:" /etc/XrayR/config.yml | grep -q "Enable: true"; then
            echo -e "${GREEN}✅ URL记录器已启用${NC}"
        else
            echo -e "${RED}❌ URL记录器未启用${NC}"
        fi
        
        if grep -A 10 "URLLoggerConfig:" /etc/XrayR/config.yml | grep -q "EnableRealtime: true"; then
            echo -e "${GREEN}✅ 实时推送已启用${NC}"
        else
            echo -e "${RED}❌ 实时推送未启用${NC}"
        fi
    else
        echo -e "${RED}❌ 缺少URL记录器配置${NC}"
    fi
    
    # 检查YAML语法
    if command -v python3 >/dev/null 2>&1; then
        if python3 -c "import yaml; yaml.safe_load(open('/etc/XrayR/config.yml'))" 2>/dev/null; then
            echo -e "${GREEN}✅ YAML语法正确${NC}"
        else
            echo -e "${RED}❌ YAML语法错误${NC}"
        fi
    fi
else
    echo -e "${RED}❌ 配置文件不存在${NC}"
fi
echo

# 5. 二进制文件检查
echo -e "${YELLOW}[5] 二进制文件检查${NC}"
if [ -f "/usr/local/bin/xrayr" ]; then
    echo -e "${GREEN}✅ 二进制文件存在${NC}"
    echo "文件路径: /usr/local/bin/xrayr"
    ls -la /usr/local/bin/xrayr
    
    if [ -x "/usr/local/bin/xrayr" ]; then
        echo -e "${GREEN}✅ 文件可执行${NC}"
        
        # 测试帮助命令
        if /usr/local/bin/xrayr --help >/dev/null 2>&1; then
            echo -e "${GREEN}✅ 二进制文件功能正常${NC}"
        else
            echo -e "${RED}❌ 二进制文件可能损坏${NC}"
        fi
    else
        echo -e "${RED}❌ 文件不可执行${NC}"
    fi
else
    echo -e "${RED}❌ 二进制文件不存在${NC}"
fi
echo

# 6. systemd服务文件检查
echo -e "${YELLOW}[6] systemd服务文件检查${NC}"
if [ -f "/etc/systemd/system/xrayr.service" ]; then
    echo -e "${GREEN}✅ 服务文件存在${NC}"
    echo "文件路径: /etc/systemd/system/xrayr.service"
    
    # 检查ExecStart命令
    if grep -q "ExecStart=/usr/local/bin/xrayr -c " /etc/systemd/system/xrayr.service; then
        echo -e "${GREEN}✅ ExecStart命令格式正确${NC}"
    elif grep -q "ExecStart=/usr/local/bin/xrayr -config " /etc/systemd/system/xrayr.service; then
        echo -e "${RED}❌ ExecStart命令格式错误 (应该使用 -c 而不是 -config)${NC}"
        echo "   建议运行: curl -L https://raw.githubusercontent.com/singlinktech/sss/main/FIX_SERVICE.sh | bash"
    else
        echo -e "${RED}❌ ExecStart命令格式未知${NC}"
    fi
else
    echo -e "${RED}❌ 服务文件不存在${NC}"
fi
echo

# 7. 防火墙状态
echo -e "${YELLOW}[7] 防火墙状态检查${NC}"
if command -v ufw >/dev/null 2>&1; then
    echo "防火墙类型: UFW"
    if ufw status | grep -q "9999"; then
        echo -e "${GREEN}✅ 端口9999已开放${NC}"
    else
        echo -e "${YELLOW}⚠️  端口9999可能未开放${NC}"
        echo "   建议运行: ufw allow 9999"
    fi
elif command -v firewall-cmd >/dev/null 2>&1; then
    echo "防火墙类型: firewalld"
    if firewall-cmd --list-ports | grep -q "9999"; then
        echo -e "${GREEN}✅ 端口9999已开放${NC}"
    else
        echo -e "${YELLOW}⚠️  端口9999可能未开放${NC}"
        echo "   建议运行: firewall-cmd --permanent --add-port=9999/tcp && firewall-cmd --reload"
    fi
else
    echo -e "${YELLOW}⚠️  未检测到防火墙管理工具${NC}"
fi
echo

# 8. 最近错误日志
echo -e "${YELLOW}[8] 最近错误日志 (最近10条)${NC}"
if journalctl -u xrayr --no-pager -l -n 10 2>/dev/null; then
    echo -e "${GREEN}✅ 日志获取成功${NC}"
else
    echo -e "${RED}❌ 无法获取服务日志${NC}"
fi
echo

# 9. 网络连接测试
echo -e "${YELLOW}[9] 网络连接测试${NC}"
if command -v python3 >/dev/null 2>&1; then
    python3 -c "
import socket
import sys

def test_connection():
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect(('127.0.0.1', 9999))
        print('${GREEN}✅ TCP连接测试: 成功${NC}')
        sock.close()
        return True
    except Exception as e:
        print('${RED}❌ TCP连接测试: 失败 - {}${NC}'.format(e))
        return False

test_connection()
"
else
    if command -v telnet >/dev/null 2>&1; then
        timeout 3 telnet 127.0.0.1 9999 </dev/null >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ telnet连接测试: 成功${NC}"
        else
            echo -e "${RED}❌ telnet连接测试: 失败${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  无法测试连接 (缺少python3和telnet)${NC}"
    fi
fi
echo

# 10. 诊断总结和建议
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}诊断总结和建议${NC}"
echo -e "${BLUE}======================================${NC}"

# 检查是否有严重问题
has_serious_issues=false

if ! systemctl is-active --quiet xrayr; then
    echo -e "${RED}🚨 严重问题: XrayR服务未运行${NC}"
    echo "   建议: systemctl start xrayr"
    has_serious_issues=true
fi

if [ ! -f "/etc/XrayR/config.yml" ]; then
    echo -e "${RED}🚨 严重问题: 配置文件缺失${NC}"
    echo "   建议: 重新运行安装脚本"
    has_serious_issues=true
fi

if [ ! -x "/usr/local/bin/xrayr" ]; then
    echo -e "${RED}🚨 严重问题: 二进制文件缺失或不可执行${NC}"
    echo "   建议: 重新安装"
    has_serious_issues=true
fi

if grep -q "ExecStart=/usr/local/bin/xrayr -config " /etc/systemd/system/xrayr.service 2>/dev/null; then
    echo -e "${RED}🚨 严重问题: systemd服务配置错误${NC}"
    echo "   建议: curl -L https://raw.githubusercontent.com/singlinktech/sss/main/FIX_SERVICE.sh | bash"
    has_serious_issues=true
fi

if ! netstat -tlnp 2>/dev/null | grep -q ":9999" && ! ss -tlnp 2>/dev/null | grep -q ":9999"; then
    echo -e "${YELLOW}⚠️  警告: 端口9999未监听${NC}"
    echo "   可能原因: 服务未启动、配置错误或防火墙阻挡"
fi

if [ "$has_serious_issues" = false ]; then
    echo -e "${GREEN}🎉 恭喜: 未发现严重问题！${NC}"
    echo "   如果仍有问题，请检查面板配置是否正确"
fi

echo
echo -e "${BLUE}快速修复命令:${NC}"
echo "重新安装: bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/ONE_CLICK_INSTALL.sh)"
echo "修复服务: curl -L https://raw.githubusercontent.com/singlinktech/sss/main/FIX_SERVICE.sh | bash"
echo "查看日志: journalctl -u xrayr -f"
echo "测试连接: xrayr-test" 