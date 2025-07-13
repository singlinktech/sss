#!/bin/bash

# 上传编译好的二进制文件到GitHub Releases
# 使用方法：./upload_release.sh <github_token>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

REPO="singlinktech/sss"
TAG="v1.0.0"
RELEASE_NAME="XrayR with URL Logger v1.0.0"
DESCRIPTION="XrayR增强版本，集成URL访问记录器和实时推送功能

## 新功能
- ✅ URL访问记录器 - 记录用户访问的网站
- ✅ 实时推送功能 - TCP端口实时推送访问数据
- ✅ 恶意网站检测 - 自动检测并标记恶意网站
- ✅ 多面板支持 - 支持V2board、SSPanel等
- ✅ 日志轮转 - 自动管理日志文件大小
- ✅ 配置简单 - 只需修改配置文件即可启用

## 快速安装
\`\`\`bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)
\`\`\`

## 配置方法
在配置文件的 ControllerConfig 中添加：
\`\`\`yaml
URLLoggerConfig:
  Enable: true
  EnableRealtime: true
  RealtimeAddr: \"127.0.0.1:9999\"
\`\`\`

更多信息请查看 [快速开始文档](https://github.com/singlinktech/sss/blob/main/QUICK_START.md)。"

if [ "$#" -ne 1 ]; then
    echo -e "${RED}使用方法: $0 <github_token>${NC}"
    echo -e "${YELLOW}请到 https://github.com/settings/tokens 创建一个personal access token${NC}"
    echo -e "${YELLOW}需要 'repo' 权限${NC}"
    exit 1
fi

GITHUB_TOKEN="$1"

# 检查二进制文件是否存在
if [ ! -f "releases/xrayr-linux-amd64" ] || [ ! -f "releases/xrayr-linux-arm64" ]; then
    echo -e "${RED}二进制文件不存在！请先编译：${NC}"
    echo "mkdir -p releases"
    echo "CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o releases/xrayr-linux-amd64 -trimpath -ldflags \"-s -w -buildid=\" ./main.go"
    echo "CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o releases/xrayr-linux-arm64 -trimpath -ldflags \"-s -w -buildid=\" ./main.go"
    exit 1
fi

echo -e "${GREEN}正在创建GitHub Release...${NC}"

# 创建release
RELEASE_RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -X POST \
    -d "{\"tag_name\":\"$TAG\",\"name\":\"$RELEASE_NAME\",\"body\":\"$DESCRIPTION\",\"draft\":false,\"prerelease\":false}" \
    "https://api.github.com/repos/$REPO/releases")

# 检查是否创建成功
if echo "$RELEASE_RESPONSE" | grep -q '"id"'; then
    echo -e "${GREEN}Release创建成功！${NC}"
    RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep '"id"' | head -1 | cut -d: -f2 | cut -d, -f1 | tr -d ' ')
    UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | grep '"upload_url"' | cut -d'"' -f4 | cut -d'{' -f1)
else
    echo -e "${RED}Release创建失败！${NC}"
    echo "$RELEASE_RESPONSE"
    exit 1
fi

echo -e "${GREEN}正在上传二进制文件...${NC}"

# 上传amd64版本
echo -e "${YELLOW}上传 xrayr-linux-amd64...${NC}"
curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @releases/xrayr-linux-amd64 \
    "${UPLOAD_URL}?name=xrayr-linux-amd64"

echo -e "${GREEN}✅ xrayr-linux-amd64 上传完成${NC}"

# 上传arm64版本
echo -e "${YELLOW}上传 xrayr-linux-arm64...${NC}"
curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/octet-stream" \
    --data-binary @releases/xrayr-linux-arm64 \
    "${UPLOAD_URL}?name=xrayr-linux-arm64"

echo -e "${GREEN}✅ xrayr-linux-arm64 上传完成${NC}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Release创建并上传成功！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}访问链接：${NC}"
echo "https://github.com/$REPO/releases/tag/$TAG"
echo ""
echo -e "${YELLOW}用户现在可以使用以下命令安装：${NC}"
echo "bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)"
echo ""
echo -e "${GREEN}安装脚本将自动下载预编译的二进制文件！${NC}" 