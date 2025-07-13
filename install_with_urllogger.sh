#!/bin/bash

# XrayR with URL Logger Installation Script
# 支持系统: CentOS 7+, Debian 8+, Ubuntu 16.04+

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# 检查系统
check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    fi
}

# 安装依赖
install_dependencies() {
    if [[ $release == "centos" ]]; then
        yum install -y wget curl tar
    else
        apt-get update
        apt-get install -y wget curl tar
    fi
}

# 下载XrayR
download_xrayr() {
    # 这里需要改成你的GitHub仓库地址
    # 示例：https://github.com/你的用户名/XrayR/releases/download/版本号/XrayR-linux-64.zip
    
    echo -e "${green}正在下载 XrayR (带URL记录功能)...${plain}"
    
    # 创建临时目录
    mkdir -p /tmp/xrayr_install
    cd /tmp/xrayr_install
    
    # 下载编译好的二进制文件
    # 你需要先在GitHub上创建一个Release并上传编译好的文件
    # wget -N --no-check-certificate -O XrayR-linux-64.zip "https://github.com/你的用户名/XrayR/releases/download/v1.0.0/XrayR-linux-64.zip"
    
    # 暂时使用本地编译的文件
    echo -e "${yellow}提示：请先将编译好的xrayr文件上传到服务器${plain}"
}

# 安装XrayR
install_xrayr() {
    echo -e "${green}开始安装 XrayR...${plain}"
    
    # 创建目录
    mkdir -p /etc/XrayR
    
    # 复制二进制文件
    cp xrayr /usr/local/bin/xrayr
    chmod +x /usr/local/bin/xrayr
    
    # 创建配置文件
    create_config
    
    # 创建systemd服务
    create_service
    
    echo -e "${green}XrayR 安装完成！${plain}"
}

# 创建配置文件
create_config() {
    cat > /etc/XrayR/config.yml <<EOF
Log:
  Level: warning
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json
RouteConfigPath: # /etc/XrayR/route.json
InboundConfigPath: # /etc/XrayR/custom_inbound.json
OutboundConfigPath: # /etc/XrayR/custom_outbound.json
ConnectionConfig:
  Handshake: 4
  ConnIdle: 30
  UplinkOnly: 2
  DownlinkOnly: 4
  BufferSize: 64
Nodes:
  - PanelType: "V2board"
    ApiConfig:
      ApiHost: "https://your-panel.com"
      ApiKey: "your-api-key"
      NodeID: 1
      NodeType: Shadowsocks
      Timeout: 60
      EnableVless: false
      VlessFlow: "xtls-rprx-vision"
      SpeedLimit: 0
      DeviceLimit: 0
      RuleListPath: # /etc/XrayR/rulelist
      DisableCustomConfig: false
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriodic: 60
      EnableDNS: false
      DNSType: AsIs
      EnableProxyProtocol: false
      AutoSpeedLimitConfig:
        Limit: 0
        WarnTimes: 0
        LimitSpeed: 0
        LimitDuration: 0
      GlobalDeviceLimitConfig:
        Enable: false
        RedisNetwork: tcp
        RedisAddr: 127.0.0.1:6379
        RedisUsername: 
        RedisPassword: YOUR_PASSWORD
        RedisDB: 0
        Timeout: 5
        Expiry: 60
      EnableFallback: false
      FallBackConfigs:
        - SNI: 
          Alpn: 
          Path: 
          Dest: 80
          ProxyProtocolVer: 0
      DisableLocalREALITYConfig: false
      EnableREALITY: false
      REALITYConfigs:
        Show: true
        Dest: www.amazon.com:443
        ProxyProtocolVer: 0
        ServerNames:
          - www.amazon.com
        PrivateKey: YOUR_PRIVATE_KEY
        MinClientVer: 
        MaxClientVer: 
        MaxTimeDiff: 0
        ShortIds:
          - ""
          - 0123456789abcdef
      CertConfig:
        CertMode: none
        CertDomain: "node1.test.com"
        CertFile: /etc/XrayR/cert/node1.test.com.cert
        KeyFile: /etc/XrayR/cert/node1.test.com.key
        Provider: alidns
        Email: test@me.com
        DNSEnv:
          ALICLOUD_ACCESS_KEY: aaa
          ALICLOUD_SECRET_KEY: bbb
      # ===== URL记录器配置 =====
      URLLoggerConfig:
        Enable: false                              # 是否启用URL记录器（默认关闭）
        LogPath: "/var/log/xrayr/url_access.log"   # 日志文件路径
        MaxFileSize: 100                           # 最大文件大小(MB)
        MaxFileCount: 10                           # 最多保留的文件数
        FlushInterval: 10                          # 刷新间隔(秒)
        EnableDomainLog: true                      # 是否记录域名访问
        EnableFullURL: false                       # 是否记录完整URL
        ExcludeDomains:                            # 排除的域名列表
          - "localhost"
          - "127.0.0.1"
        # ===== 实时推送配置 =====
        EnableRealtime: false                      # 是否启用实时推送（默认关闭）
        RealtimeAddr: "127.0.0.1:9999"             # 实时推送监听地址
EOF
}

# 创建systemd服务
create_service() {
    cat > /etc/systemd/system/xrayr.service <<EOF
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

    systemctl daemon-reload
    systemctl enable xrayr
}

# 显示使用说明
show_usage() {
    echo -e "${green}XrayR with URL Logger 安装完成！${plain}"
    echo -e ""
    echo -e "使用方法："
    echo -e "  启动: systemctl start xrayr"
    echo -e "  停止: systemctl stop xrayr"
    echo -e "  重启: systemctl restart xrayr"
    echo -e "  状态: systemctl status xrayr"
    echo -e "  日志: journalctl -u xrayr -f"
    echo -e ""
    echo -e "${yellow}配置文件: /etc/XrayR/config.yml${plain}"
    echo -e ""
    echo -e "${green}URL记录器功能说明：${plain}"
    echo -e "1. 编辑配置文件，设置 URLLoggerConfig 下的 Enable: true"
    echo -e "2. 如需实时推送，设置 EnableRealtime: true"
    echo -e "3. 重启服务生效: systemctl restart xrayr"
    echo -e ""
    echo -e "${yellow}重要：请先修改配置文件中的面板信息！${plain}"
}

# 主函数
main() {
    check_sys
    install_dependencies
    
    echo -e "${green}安装 XrayR with URL Logger${plain}"
    echo -e "${green}1. 请先编译XrayR并上传到服务器${plain}"
    echo -e "${green}2. 将编译好的 xrayr 文件放在当前目录${plain}"
    echo -e ""
    
    read -p "是否已准备好编译文件？[y/n]: " choice
    case "$choice" in
        y|Y)
            if [[ -f "xrayr" ]]; then
                install_xrayr
                show_usage
            else
                echo -e "${red}错误：当前目录下没有找到 xrayr 文件${plain}"
                exit 1
            fi
            ;;
        *)
            echo -e "${yellow}请先准备好文件再运行此脚本${plain}"
            exit 0
            ;;
    esac
}

main "$@" 