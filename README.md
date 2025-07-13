# XrayR with URL Logger

XrayR 增强版本，集成了 URL 访问记录器和实时推送功能。

## 🚀 特性

- ✅ **URL 访问记录器** - 记录用户访问的网站
- ✅ **实时推送功能** - TCP 端口实时推送访问数据
- ✅ **恶意网站检测** - 自动检测并标记恶意网站
- ✅ **多面板支持** - 支持 V2board、SSPanel 等
- ✅ **日志轮转** - 自动管理日志文件大小
- ✅ **配置简单** - 只需修改配置文件即可启用

## 📦 快速安装

### 一键安装（推荐）

```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)
```

### 配置和启动

1. 修改配置文件：
```bash
nano /etc/XrayR/config.yml
```

2. 启动服务：
```bash
systemctl start xrayr
```

3. 监控访问：
```bash
xrayr-monitor
```

详细说明请查看 [快速开始文档](QUICK_START.md)。

## 📊 数据格式

### URL 访问日志
```json
{
  "request_time": "2024-01-01T12:00:00Z",
  "user_id": 123,
  "email": "user@example.com",
  "domain": "example.com",
  "protocol": "shadowsocks",
  "source_ip": "1.2.3.4"
}
```

### 实时推送数据
实时推送服务器默认在端口 9999 上运行，推送 JSON 格式的访问数据。

## 🛠️ 项目结构

```
XrayR-master/
├── EASY_INSTALL.sh          # 简化安装脚本
├── QUICK_START.md           # 3分钟快速开始
├── common/urllogger/        # URL记录器核心模块
├── app/mydispatcher/        # 流量分发器集成
├── service/controller/      # 控制器集成
└── examples/               # 示例代码
```

## 📚 文档

- [快速开始](QUICK_START.md) - 3分钟快速部署
- [完整部署指南](DEPLOYMENT_COMPLETE_GUIDE.md) - 详细部署说明
- [URL记录器文档](URL_ACCESS_LOGGER.md) - 功能详细说明

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目基于 MIT 许可证开源。

---

**⚡ 特别说明：**
- 🔥 无需编译，直接下载预编译版本
- 🚀 3分钟快速部署
- 💪 完全兼容原版 XrayR
- 🔒 不影响现有功能和性能
