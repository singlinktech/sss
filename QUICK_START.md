# 超快速开始 - 3分钟搞定！

## 第一步：运行安装脚本（30秒）

在你的服务器上运行：

```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/EASY_INSTALL.sh)
```

这个脚本会：
- ✅ 下载已经编译好的XrayR（带URL记录功能）
- ✅ 自动创建系统服务
- ✅ 无需安装Go，无需等待编译

## 第二步：修改配置文件（2分钟）

编辑你的配置文件：
```bash
nano /etc/XrayR/config.yml
```

找到你的节点配置，在 `ControllerConfig:` 里面，`CertConfig:` 后面，添加这段：

```yaml
      # URL记录器配置
      URLLoggerConfig:
        Enable: true                               # 开启
        LogPath: "/var/log/xrayr/url_access.log"  # 日志文件
        EnableRealtime: true                      # 开启实时推送
        RealtimeAddr: "127.0.0.1:9999"           # 监听端口
```

**注意缩进！要和 CertConfig 对齐！**

## 第三步：启动服务（30秒）

```bash
# 启动
systemctl start xrayr

# 查看状态
systemctl status xrayr
```

## 完成！开始使用

### 查看实时数据
```bash
nc localhost 9999
```

### 查看日志文件
```bash
tail -f /var/log/xrayr/url_access.log
```

### 检查是否工作
```bash
journalctl -u xrayr | grep -E "URL记录器|实时推送"
```

应该看到：
```
URL记录器启动成功 path=/var/log/xrayr/url_access.log
实时推送服务器已启动 address=127.0.0.1:9999
```

## 故障排除

### 如果没有记录？

1. 确认配置中 `Enable: true`
2. 确认有用户在使用代理
3. 重启服务：`systemctl restart xrayr`

### 如果下载失败？

手动下载：
```bash
# Linux amd64
wget https://github.com/singlinktech/sss/releases/download/v1.0.0/xrayr-linux-amd64

# Linux arm64
wget https://github.com/singlinktech/sss/releases/download/v1.0.0/xrayr-linux-arm64

chmod +x xrayr-linux-*
mv xrayr-linux-* /usr/local/bin/xrayr
```

## 就这么简单！

- 不需要编译
- 不需要Go环境
- 只需要改配置文件
- 3分钟搞定！

---

**提示**：如果你想看更详细的功能说明，查看 [完整文档](DEPLOYMENT_COMPLETE_GUIDE.md) 