# 创建 GitHub Release 说明

## 1. 编译已完成

已编译好的二进制文件位于 `releases/` 目录：
- `xrayr-linux-amd64` (128MB)
- `xrayr-linux-arm64` (123MB)

## 2. 创建 GitHub Release

### 步骤1：访问 GitHub Releases 页面
打开浏览器，访问：https://github.com/singlinktech/sss/releases

### 步骤2：点击 "Create a new release"

### 步骤3：填写 Release 信息
- **Tag version**: `v1.0.0`
- **Release title**: `XrayR with URL Logger v1.0.0`
- **Description**: 复制以下内容

```markdown
XrayR增强版本，集成URL访问记录器和实时推送功能

## 🚀 新功能
- ✅ **URL访问记录器** - 记录用户访问的网站
- ✅ **实时推送功能** - TCP端口实时推送访问数据
- ✅ **恶意网站检测** - 自动检测并标记恶意网站
- ✅ **多面板支持** - 支持V2board、SSPanel等
- ✅ **日志轮转** - 自动管理日志文件大小
- ✅ **配置简单** - 只需修改配置文件即可启用

## 📦 快速安装
```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)
```

## ⚙️ 配置方法
在配置文件的 `ControllerConfig` 中添加：
```yaml
URLLoggerConfig:
  Enable: true
  EnableRealtime: true
  RealtimeAddr: "127.0.0.1:9999"
```

## 📚 文档
- [快速开始文档](https://github.com/singlinktech/sss/blob/main/QUICK_START.md)
- [完整部署指南](https://github.com/singlinktech/sss/blob/main/DEPLOYMENT_COMPLETE_GUIDE.md)

## 🔧 支持的架构
- Linux amd64
- Linux arm64

## 💡 特别说明
- 🔥 无需编译，直接下载预编译版本
- 🚀 3分钟快速部署
- 💪 完全兼容原版XrayR
- 🔒 不影响现有功能和性能
```

### 步骤4：上传二进制文件
在 Release 页面的 "Attach binaries" 部分，拖拽或点击上传以下文件：
- `releases/xrayr-linux-amd64`
- `releases/xrayr-linux-arm64`

### 步骤5：发布 Release
点击 "Publish release" 按钮

## 3. 验证安装脚本

Release 创建完成后，你可以测试安装脚本：

```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)
```

## 4. 自动化脚本（可选）

如果你有 GitHub Personal Access Token，可以使用自动化脚本：

```bash
chmod +x upload_release.sh
./upload_release.sh <your_github_token>
```

创建 Token 地址：https://github.com/settings/tokens
需要 `repo` 权限。

---

**完成后，用户就可以直接使用简化的安装脚本，无需在服务器上编译！** 