# 🚨 紧急发布指南 - 立即修复安装脚本

## 当前状态
- ✅ 二进制文件已编译完成
- ❌ GitHub Release 未创建（导致安装脚本404错误）
- ⏰ 需要立即创建Release

## 📋 5分钟解决步骤

### 步骤1：访问GitHub Release页面
打开浏览器，复制粘贴这个链接：
```
https://github.com/singlinktech/sss/releases
```

### 步骤2：创建新Release
点击右上角绿色按钮：**"Create a new release"**

### 步骤3：填写Release信息
- **Tag version**: `v1.0.0`
- **Release title**: `XrayR with URL Logger v1.0.0`
- **Description**: 复制下面的内容到描述框

```markdown
XrayR增强版本，集成URL访问记录器和实时推送功能

## 🚀 新功能
- ✅ **URL访问记录器** - 记录用户访问的网站
- ✅ **实时推送功能** - TCP端口实时推送访问数据
- ✅ **恶意网站检测** - 自动检测并标记恶意网站
- ✅ **多面板支持** - 支持V2board、SSPanel等
- ✅ **日志轮转** - 自动管理日志文件大小
- ✅ **配置简单** - 只需修改配置文件即可启用

## 📦 一键安装
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
在页面底部找到 **"Attach binaries by dropping them here or selecting them"**

**重要：** 上传以下两个文件：
- `releases/xrayr-linux-amd64` (128MB)
- `releases/xrayr-linux-arm64` (123MB)

**上传方法：**
- 方法1：直接拖拽文件到指定区域
- 方法2：点击选择文件

### 步骤5：发布Release
确认信息无误后，点击绿色按钮：**"Publish release"**

## 🎉 完成！

发布完成后，用户立即可以使用：
```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)
```

## 📍 二进制文件位置
本地文件在：
- `releases/xrayr-linux-amd64`
- `releases/xrayr-linux-arm64`

---

**⏰ 预计完成时间：5分钟**  
**🎯 完成后立即解决用户的404错误问题** 