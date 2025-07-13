#!/bin/bash

# XrayR URL Logger 超简单安装脚本
# 直接下载预编译版本，无需编译

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}XrayR URL记录器 - 快速安装${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查是否为root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用root用户运行此脚本${NC}"
    exit 1
fi

# 检测架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${RED}不支持的架构: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}检测到系统架构: $ARCH${NC}"

# 备份配置
if [ -f "/etc/XrayR/config.yml" ]; then
    echo -e "${YELLOW}备份现有配置...${NC}"
    cp /etc/XrayR/config.yml /etc/XrayR/config.yml.bak.$(date +%Y%m%d_%H%M%S)
fi

# 停止服务
echo -e "${YELLOW}停止XrayR服务...${NC}"
systemctl stop xrayr 2>/dev/null || true
systemctl stop XrayR 2>/dev/null || true

# 下载预编译版本
echo -e "${GREEN}下载XrayR (带URL记录功能)...${NC}"

# GitHub Release下载地址
DOWNLOAD_URL="https://github.com/singlinktech/sss/releases/latest/download/xrayr-linux-${ARCH}"

# 创建临时目录
TMP_DIR=$(mktemp -d)
cd $TMP_DIR

# 下载二进制文件
echo -e "${YELLOW}正在下载...${NC}"
if wget -O xrayr "$DOWNLOAD_URL" 2>/dev/null || curl -L -o xrayr "$DOWNLOAD_URL" 2>/dev/null; then
    echo -e "${GREEN}下载成功！${NC}"
else
    echo -e "${RED}下载失败！${NC}"
    echo -e "${YELLOW}临时解决方案：从备用地址下载...${NC}"
    # 备用下载地址
    wget -O xrayr "https://raw.githubusercontent.com/singlinktech/sss/main/releases/xrayr-linux-${ARCH}" || {
        echo -e "${RED}下载失败，请检查网络连接${NC}"
        exit 1
    }
fi

# 安装
echo -e "${GREEN}安装XrayR...${NC}"
chmod +x xrayr
mv xrayr /usr/local/bin/xrayr

# 创建软链接
ln -sf /usr/local/bin/xrayr /usr/bin/xrayr
ln -sf /usr/local/bin/xrayr /usr/bin/XrayR

# 创建必要的目录
mkdir -p /etc/XrayR
mkdir -p /var/log/xrayr

# 下载geo数据文件
echo -e "${GREEN}下载geo数据文件...${NC}"
cd /etc/XrayR
for file in geoip.dat geosite.dat; do
    if [ ! -f "$file" ]; then
        wget -q "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/$file" || \
        wget -q "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/$file" || \
        echo -e "${YELLOW}警告: 无法下载 $file${NC}"
    fi
done

# 创建systemd服务
echo -e "${GREEN}创建系统服务...${NC}"
cat > /etc/systemd/system/xrayr.service << 'EOF'
[Unit]
Description=XrayR Service with URL Logger
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/xrayr -c /etc/XrayR/config.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 兼容旧服务名
ln -sf /etc/systemd/system/xrayr.service /etc/systemd/system/XrayR.service

# 重载systemd
systemctl daemon-reload
systemctl enable xrayr

# 清理
cd /
rm -rf $TMP_DIR

# 显示配置示例
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}【重要】请修改配置文件以启用URL记录功能：${NC}"
echo ""
echo "1. 编辑配置文件："
echo "   nano /etc/XrayR/config.yml"
echo ""
echo "2. 在你的节点配置中，找到 ControllerConfig 部分"
echo "   在 CertConfig 之后添加以下内容："
echo ""
echo -e "${GREEN}      # URL记录器配置${NC}"
echo -e "${GREEN}      URLLoggerConfig:${NC}"
echo -e "${GREEN}        Enable: true                               # 启用URL记录${NC}"
echo -e "${GREEN}        LogPath: \"/var/log/xrayr/url_access.log\"  # 日志文件路径${NC}"
echo -e "${GREEN}        MaxFileSize: 100                          # 文件最大100MB${NC}"
echo -e "${GREEN}        MaxFileCount: 10                          # 保留10个文件${NC}"
echo -e "${GREEN}        FlushInterval: 10                         # 10秒刷新一次${NC}"
echo -e "${GREEN}        EnableDomainLog: true                     # 记录域名${NC}"
echo -e "${GREEN}        EnableFullURL: false                      # 不记录完整URL${NC}"
echo -e "${GREEN}        ExcludeDomains:                           # 排除的域名${NC}"
echo -e "${GREEN}          - \"localhost\"${NC}"
echo -e "${GREEN}          - \"127.0.0.1\"${NC}"
echo -e "${GREEN}        EnableRealtime: true                      # 启用实时推送${NC}"
echo -e "${GREEN}        RealtimeAddr: \"127.0.0.1:9999\"           # 监听地址${NC}"
echo ""
echo "3. 启动服务："
echo "   systemctl start xrayr"
echo ""
echo "4. 查看状态："
echo "   systemctl status xrayr"
echo ""
echo "5. 查看日志确认URL记录器启动："
echo "   journalctl -u xrayr | grep -E 'URL记录器|实时推送'"
echo ""
echo "6. 监控实时数据："
echo "   nc localhost 9999"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}注意：如果下载失败，请先在本地编译并上传到GitHub Release${NC}"
echo -e "${GREEN}========================================${NC}" 