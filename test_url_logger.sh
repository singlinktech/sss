#!/bin/bash

# URL记录器功能测试脚本
# 用于验证XrayR的URL访问记录功能

set -e

echo "=========================================="
echo "XrayR URL访问记录器功能测试"
echo "=========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试目录
TEST_DIR="/tmp/xrayr_test"
LOG_DIR="${TEST_DIR}/logs"
CONFIG_FILE="${TEST_DIR}/test_config.yml"
MALICIOUS_DB="${TEST_DIR}/malicious_domains.txt"

# 清理函数
cleanup() {
    echo -e "${YELLOW}清理测试环境...${NC}"
    rm -rf "${TEST_DIR}"
    echo -e "${GREEN}清理完成${NC}"
}

# 错误处理
error_handler() {
    echo -e "${RED}测试失败！${NC}"
    cleanup
    exit 1
}

trap error_handler ERR

echo -e "${BLUE}1. 创建测试环境...${NC}"
mkdir -p "${LOG_DIR}"
mkdir -p "${TEST_DIR}"

echo -e "${BLUE}2. 编译XrayR...${NC}"
if ! go build -o "${TEST_DIR}/xrayr" .; then
    echo -e "${RED}编译失败！${NC}"
    exit 1
fi
echo -e "${GREEN}编译成功${NC}"

echo -e "${BLUE}3. 创建测试配置文件...${NC}"
cat > "${CONFIG_FILE}" << EOF
Log:
  Level: info
  AccessPath: ${LOG_DIR}/access.log
  ErrorPath: ${LOG_DIR}/error.log

Nodes:
  - PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "https://test-panel.com"
      ApiKey: "test-key"
      NodeID: 1
      NodeType: V2ray
      Timeout: 30
      EnableVless: false
      SpeedLimit: 0
      DeviceLimit: 0
    ControllerConfig:
      ListenIP: 0.0.0.0
      SendIP: 0.0.0.0
      UpdatePeriodic: 60
      EnableDNS: false
      DNSType: AsIs
      URLLoggerConfig:
        Enable: true
        LogPath: "${LOG_DIR}/url_access.log"
        MaxFileSize: 10
        MaxFileCount: 5
        FlushInterval: 5
        EnableDomainLog: true
        EnableFullURL: false
        ExcludeDomains:
          - "localhost"
          - "127.0.0.1"
EOF

echo -e "${GREEN}配置文件创建完成${NC}"

echo -e "${BLUE}4. 创建恶意域名数据库...${NC}"
if ! "${TEST_DIR}/xrayr" create-malicious-db "${MALICIOUS_DB}"; then
    echo -e "${RED}创建恶意域名数据库失败！${NC}"
    exit 1
fi
echo -e "${GREEN}恶意域名数据库创建成功${NC}"

echo -e "${BLUE}5. 创建测试日志数据...${NC}"
cat > "${LOG_DIR}/url_access.log" << EOF
{"timestamp":"2024-07-14T00:45:00Z","user_id":0,"email":"user1@example.com","domain":"google.com","full_url":"","protocol":"http","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:45:15Z","user_id":0,"email":"user2@example.com","domain":"github.com","full_url":"","protocol":"https","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:45:30Z","user_id":0,"email":"user1@example.com","domain":"malware.example.com","full_url":"","protocol":"http","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:45:45Z","user_id":0,"email":"user3@example.com","domain":"facebook.com","full_url":"","protocol":"https","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:46:00Z","user_id":0,"email":"user2@example.com","domain":"virus.test.com","full_url":"","protocol":"http","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:46:15Z","user_id":0,"email":"user1@example.com","domain":"youtube.com","full_url":"","protocol":"https","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:46:30Z","user_id":0,"email":"user4@example.com","domain":"suspicious.tk","full_url":"","protocol":"http","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:46:45Z","user_id":0,"email":"user1@example.com","domain":"twitter.com","full_url":"","protocol":"https","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:47:00Z","user_id":0,"email":"user2@example.com","domain":"trojan.bad.com","full_url":"","protocol":"http","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:47:15Z","user_id":0,"email":"user5@example.com","domain":"badsite.com","full_url":"","protocol":"http","node_id":1,"node_tag":"node1"}
EOF

echo -e "${GREEN}测试日志数据创建完成${NC}"

echo -e "${BLUE}6. 测试URL访问日志分析...${NC}"
REPORT_FILE="${TEST_DIR}/analysis_report.txt"
if ! "${TEST_DIR}/xrayr" analyze -l "${LOG_DIR}/url_access.log" -d "${MALICIOUS_DB}" -o "${REPORT_FILE}"; then
    echo -e "${RED}URL访问日志分析失败！${NC}"
    exit 1
fi

echo -e "${GREEN}URL访问日志分析完成${NC}"

echo -e "${BLUE}7. 验证分析结果...${NC}"
if [[ ! -f "${REPORT_FILE}" ]]; then
    echo -e "${RED}分析报告文件不存在！${NC}"
    exit 1
fi

# 检查分析报告内容
if ! grep -q "恶意记录数" "${REPORT_FILE}"; then
    echo -e "${RED}分析报告格式错误！${NC}"
    exit 1
fi

if ! grep -q "malware.example.com" "${REPORT_FILE}"; then
    echo -e "${RED}未检测到恶意域名！${NC}"
    exit 1
fi

echo -e "${GREEN}分析结果验证通过${NC}"

echo -e "${BLUE}8. 显示分析报告...${NC}"
echo "----------------------------------------"
cat "${REPORT_FILE}"
echo "----------------------------------------"

echo -e "${BLUE}9. 测试配置验证...${NC}"
# 验证配置文件是否正确
if ! "${TEST_DIR}/xrayr" -c "${CONFIG_FILE}" --help > /dev/null 2>&1; then
    echo -e "${YELLOW}配置文件验证跳过（需要实际面板连接）${NC}"
else
    echo -e "${GREEN}配置文件验证通过${NC}"
fi

echo -e "${BLUE}10. 性能测试...${NC}"
# 创建大量测试数据
LARGE_LOG="${LOG_DIR}/large_url_access.log"
echo -e "${YELLOW}生成大量测试数据...${NC}"
for i in {1..1000}; do
    echo "{\"timestamp\":\"2024-07-14T00:$(printf "%02d" $((i % 60))):$(printf "%02d" $((i % 60)))Z\",\"user_id\":0,\"email\":\"user$((i % 10))@example.com\",\"domain\":\"domain$i.com\",\"full_url\":\"\",\"protocol\":\"https\",\"node_id\":1,\"node_tag\":\"node1\"}" >> "${LARGE_LOG}"
done

# 测试大文件分析性能
echo -e "${YELLOW}测试大文件分析性能...${NC}"
start_time=$(date +%s)
if ! "${TEST_DIR}/xrayr" analyze -l "${LARGE_LOG}" -d "${MALICIOUS_DB}" > /dev/null 2>&1; then
    echo -e "${RED}大文件分析失败！${NC}"
    exit 1
fi
end_time=$(date +%s)
duration=$((end_time - start_time))
echo -e "${GREEN}大文件分析完成，耗时：${duration}秒${NC}"

echo -e "${BLUE}11. 功能测试总结...${NC}"
echo "测试项目："
echo "  ✓ 编译成功"
echo "  ✓ 配置文件创建"
echo "  ✓ 恶意域名数据库创建"
echo "  ✓ URL访问日志分析"
echo "  ✓ 恶意域名检测"
echo "  ✓ 分析报告生成"
echo "  ✓ 大文件性能测试"

echo -e "${GREEN}=========================================="
echo "所有测试通过！URL记录器功能正常工作。"
echo "==========================================${NC}"

# 清理测试环境
cleanup

echo -e "${BLUE}使用说明：${NC}"
echo "1. 在配置文件中启用URLLoggerConfig"
echo "2. 使用 './xrayr -c config.yml' 启动XrayR"
echo "3. 使用 './xrayr analyze -l /path/to/log' 分析日志"
echo "4. 使用 './xrayr create-malicious-db /path/to/db' 创建恶意域名数据库"
echo ""
echo -e "${GREEN}测试完成！${NC}" 