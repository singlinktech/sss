# 🔧 XrayR 故障排除指南

## 🚨 常见问题及解决方案

### ❌ 问题1: 服务启动失败 - "unknown command"

**错误信息**:
```
time="2025-07-14T05:48:24+08:00" level=fatal msg="unknown command \"/etc/XrayR/config.yml\" for \"XrayR\""
```

**原因**: systemd服务文件中的参数格式错误

**解决方案** (3种方法):

#### 方法1: 使用快速修复脚本 (推荐)
```bash
curl -L https://raw.githubusercontent.com/singlinktech/sss/main/FIX_SERVICE.sh | bash
```

#### 方法2: 手动修复
```bash
# 停止服务
systemctl stop xrayr

# 修复服务文件
sudo tee /etc/systemd/system/xrayr.service > /dev/null << 'EOF'
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

# 重载并启动
systemctl daemon-reload
systemctl start xrayr
```

#### 方法3: 重新安装 (最新版本已修复)
```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/ONE_CLICK_INSTALL.sh)
```

---

### ❌ 问题2: 端口9999未监听

**检查方法**:
```bash
netstat -tlnp | grep 9999
# 或
ss -tlnp | grep 9999
```

**可能原因和解决方案**:

1. **配置文件错误**
   ```bash
   # 检查配置文件
   nano /etc/XrayR/config.yml
   
   # 确保包含以下配置
   URLLoggerConfig:
     Enable: true
     EnableRealtime: true
     RealtimeAddr: "0.0.0.0:9999"
   ```

2. **面板配置不正确**
   ```bash
   # 修改面板配置
   nano /etc/XrayR/config.yml
   
   # 必须修改:
   ApiHost: "https://你的面板.com"
   ApiKey: "你的API密钥"
   NodeID: 你的节点ID
   ```

3. **防火墙阻挡**
   ```bash
   # 开放端口
   ufw allow 9999  # Ubuntu/Debian
   firewall-cmd --permanent --add-port=9999/tcp && firewall-cmd --reload  # CentOS
   ```

---

### ❌ 问题3: 配置文件格式错误

**验证配置**:
```bash
# 检查YAML语法
python3 -c "import yaml; yaml.safe_load(open('/etc/XrayR/config.yml'))" 
```

**常见格式错误**:
- 缩进不正确 (必须使用空格，不能使用Tab)
- 冒号后缺少空格
- 引号不匹配

**获取正确的配置模板**:
```bash
curl -L https://raw.githubusercontent.com/singlinktech/sss/main/config_examples/realtime_only_config.yml > /etc/XrayR/config.yml
```

---

### ❌ 问题4: 二进制文件权限或损坏

**检查二进制文件**:
```bash
# 检查文件是否存在且可执行
ls -la /usr/local/bin/xrayr

# 测试二进制文件
/usr/local/bin/xrayr --help
```

**解决方案**:
```bash
# 重新下载二进制文件
wget -O /tmp/xrayr-linux-amd64 "https://github.com/singlinktech/sss/releases/latest/download/xrayr-linux-amd64"
chmod +x /tmp/xrayr-linux-amd64
mv /tmp/xrayr-linux-amd64 /usr/local/bin/xrayr
```

---

### ❌ 问题5: 没有数据输出

**诊断步骤**:

1. **检查服务状态**
   ```bash
   systemctl status xrayr
   xrayr-test  # 如果可用
   ```

2. **检查连接**
   ```bash
   telnet 127.0.0.1 9999
   ```

3. **手动测试连接**
   ```bash
   python3 -c "
   import socket
   sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
   sock.settimeout(5)
   try:
       sock.connect(('127.0.0.1', 9999))
       print('连接成功')
   except Exception as e:
       print(f'连接失败: {e}')
   finally:
       sock.close()
   "
   ```

**可能原因**:
- 没有用户使用代理
- 面板配置不正确
- URL记录器未启用

---

## 🔍 诊断工具

### 完整诊断脚本
```bash
#!/bin/bash
echo "=== XrayR 诊断报告 ==="
echo "时间: $(date)"
echo

echo "1. 服务状态:"
systemctl status xrayr --no-pager -l || echo "服务不存在"
echo

echo "2. 端口监听:"
netstat -tlnp | grep 9999 || echo "端口9999未监听"
echo

echo "3. 配置文件:"
if [ -f "/etc/XrayR/config.yml" ]; then
    echo "配置文件存在"
    echo "大小: $(wc -l < /etc/XrayR/config.yml) 行"
else
    echo "配置文件不存在"
fi
echo

echo "4. 二进制文件:"
if [ -x "/usr/local/bin/xrayr" ]; then
    echo "二进制文件存在且可执行"
    ls -la /usr/local/bin/xrayr
else
    echo "二进制文件不存在或不可执行"
fi
echo

echo "5. 最近日志:"
journalctl -u xrayr --no-pager -l -n 5 2>/dev/null || echo "无法获取日志"
```

### 保存为文件并运行
```bash
curl -L https://raw.githubusercontent.com/singlinktech/sss/main/scripts/diagnose.sh | bash
```

---

## 🚀 快速修复命令

### 一键重新安装 (最简单)
```bash
bash <(curl -L https://raw.githubusercontent.com/singlinktech/sss/main/ONE_CLICK_INSTALL.sh)
```

### 快速修复服务 (保留配置)
```bash
curl -L https://raw.githubusercontent.com/singlinktech/sss/main/FIX_SERVICE.sh | bash
```

### 重启所有服务
```bash
systemctl daemon-reload
systemctl restart xrayr
systemctl status xrayr
```

---

## 📞 获取帮助

如果以上方法都无法解决问题，请提供以下信息：

1. **系统信息**:
   ```bash
   uname -a
   cat /etc/os-release
   ```

2. **完整错误日志**:
   ```bash
   journalctl -u xrayr --no-pager -l -n 20
   ```

3. **配置文件** (去除敏感信息):
   ```bash
   cat /etc/XrayR/config.yml | sed 's/ApiKey:.*/ApiKey: "***"/'
   ```

4. **诊断报告**:
   ```bash
   curl -L https://raw.githubusercontent.com/singlinktech/sss/main/scripts/diagnose.sh | bash
   ```

**提交问题**: https://github.com/singlinktech/sss/issues

---

## 🎯 预防措施

1. **定期检查服务状态**
   ```bash
   # 添加到crontab
   */5 * * * * systemctl is-active --quiet xrayr || systemctl restart xrayr
   ```

2. **监控端口状态**
   ```bash
   # 简单监控脚本
   if ! netstat -tlnp | grep -q ":9999"; then
       echo "端口9999未监听，重启服务"
       systemctl restart xrayr
   fi
   ```

3. **配置备份**
   ```bash
   # 定期备份配置
   cp /etc/XrayR/config.yml /etc/XrayR/config.yml.backup.$(date +%Y%m%d)
   ``` 