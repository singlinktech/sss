# XrayR URL访问记录器

## 功能概述

URL访问记录器是XrayR新增的功能，用于记录用户访问的URL地址，帮助管理员分析用户是否访问恶意网站。该功能具有以下特点：

- **无侵入性**：不影响现有的代理功能和性能
- **可配置**：支持灵活的配置选项
- **高效率**：使用缓冲区和异步写入提高性能
- **完整性**：支持日志轮转和恶意域名检测
- **实时性**：支持实时分析和报告生成

## 架构说明

### 核心组件

1. **URLLogger** (`common/urllogger/urllogger.go`)
   - 负责记录URL访问日志
   - 支持缓冲区和异步写入
   - 支持日志文件轮转

2. **Analyzer** (`common/urllogger/analyzer.go`)
   - 负责分析URL访问日志
   - 检测恶意域名访问
   - 生成分析报告

3. **MyDispatcher集成** (`app/mydispatcher/default.go`)
   - 在流量分发过程中记录URL访问
   - 不影响现有的规则检测和流量处理

4. **Controller集成** (`service/controller/`)
   - 在controller中初始化和管理URL记录器
   - 支持配置热更新

## 配置说明

### 基本配置

在XrayR的配置文件中，在`ControllerConfig`部分添加`URLLoggerConfig`：

```yaml
ControllerConfig:
  # ... 其他配置
  URLLoggerConfig:
    Enable: true                                    # 是否启用URL记录器
    LogPath: "/var/log/xrayr/url_access.log"       # 日志文件路径
    MaxFileSize: 100                               # 最大文件大小(MB)
    MaxFileCount: 10                               # 最多保留的文件数
    FlushInterval: 10                              # 刷新间隔(秒)
    EnableDomainLog: true                          # 是否记录域名访问
    EnableFullURL: false                           # 是否记录完整URL
    ExcludeDomains:                                # 排除的域名列表
      - "example.com"
      - "localhost"
      - "127.0.0.1"
```

### 配置参数详解

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `Enable` | bool | false | 是否启用URL记录器 |
| `LogPath` | string | "/var/log/xrayr/url_access.log" | 日志文件路径 |
| `MaxFileSize` | int64 | 100 | 单个日志文件的最大大小(MB) |
| `MaxFileCount` | int | 10 | 最多保留的日志文件数量 |
| `FlushInterval` | int | 10 | 缓冲区刷新间隔(秒) |
| `EnableDomainLog` | bool | true | 是否记录域名访问 |
| `EnableFullURL` | bool | false | 是否记录完整URL(包含路径和参数) |
| `ExcludeDomains` | []string | [] | 排除记录的域名列表 |

## 使用示例

### 1. 启用URL记录器

创建配置文件 `config.yml`：

```yaml
Log:
  Level: info
  
Nodes:
  - PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "https://your-panel.com"
      ApiKey: "your-api-key"
      NodeID: 1
      NodeType: V2ray
    ControllerConfig:
      ListenIP: 0.0.0.0
      UpdatePeriodic: 60
      # 启用URL记录器
      URLLoggerConfig:
        Enable: true
        LogPath: "/var/log/xrayr/url_access.log"
        MaxFileSize: 100
        MaxFileCount: 10
        FlushInterval: 10
        EnableDomainLog: true
        EnableFullURL: false
        ExcludeDomains:
          - "googleapis.com"
          - "cloudflare.com"
```

### 2. 启动XrayR

```bash
./xrayr -c config.yml
```

### 3. 查看日志

```bash
tail -f /var/log/xrayr/url_access.log
```

日志格式示例：
```json
{"timestamp":"2024-07-14T00:45:00Z","user_id":0,"email":"user1@example.com","domain":"google.com","full_url":"","protocol":"http","node_id":1,"node_tag":"node1"}
{"timestamp":"2024-07-14T00:45:15Z","user_id":0,"email":"user2@example.com","domain":"github.com","full_url":"","protocol":"https","node_id":1,"node_tag":"node1"}
```

## 日志分析

### 使用内置分析工具

XrayR提供了内置的URL访问日志分析工具：

#### 1. 创建恶意域名数据库

```bash
./xrayr create-malicious-db /etc/xrayr/malicious_domains.txt
```

#### 2. 分析日志文件

```bash
# 基本分析
./xrayr analyze -l /var/log/xrayr/url_access.log

# 使用恶意域名数据库
./xrayr analyze -l /var/log/xrayr/url_access.log -d /etc/xrayr/malicious_domains.txt

# 输出报告到文件
./xrayr analyze -l /var/log/xrayr/url_access.log -o /tmp/analysis_report.txt
```

#### 3. 分析报告示例

```
URL访问分析报告
================
分析时间: 2024-07-14 00:46:31
总记录数: 20
恶意记录数: 3
可疑用户数: 1

恶意访问记录:
-------------
时间: 2024-07-14 00:45:30 | 用户: user1@example.com | 域名: malware.example.com | 原因: 域名在恶意域名列表中 | 严重程度: high
时间: 2024-07-14 00:46:00 | 用户: user2@example.com | 域名: virus.test.com | 原因: 域名在恶意域名列表中 | 严重程度: high
时间: 2024-07-14 00:47:45 | 用户: user1@example.com | 域名: phishing.fake.com | 原因: 域名在恶意域名列表中 | 严重程度: high

可疑用户:
--------
- user1@example.com(0)

热门域名:
--------
1. google.com (访问次数: 5)
2. github.com (访问次数: 3)
3. youtube.com (访问次数: 2)
```

## 恶意域名检测

### 内置检测规则

URL记录器包含以下内置检测规则：

1. **恶意软件域名**：检测包含malware、virus、trojan、botnet、phishing关键词的域名
2. **可疑顶级域名**：检测使用.tk、.ml、.ga、.cf、.gq等免费顶级域名
3. **Tor出口节点**：检测.onion域名
4. **可疑子域名**：检测包含admin、login、secure、bank、pay、account等关键词的可疑子域名
5. **DGA域名**：检测可能由域名生成算法(DGA)产生的域名

### 自定义恶意域名列表

创建恶意域名列表文件：

```bash
# 创建文件
vi /etc/xrayr/malicious_domains.txt

# 添加恶意域名，每行一个
malware.example.com
virus.test.com
trojan.bad.com
phishing.fake.com
```

## 性能优化

### 缓冲区机制

- URL记录器使用内存缓冲区，减少磁盘写入频率
- 支持配置刷新间隔，平衡性能和实时性

### 异步处理

- 日志写入使用异步机制，不阻塞主要流量处理
- 支持批量写入，提高效率

### 日志轮转

- 支持按文件大小自动轮转
- 支持配置保留文件数量，防止磁盘空间不足

## 故障排除

### 常见问题

1. **日志文件创建失败**
   - 检查目录权限
   - 确保日志目录存在
   - 检查磁盘空间

2. **性能影响**
   - 调整刷新间隔
   - 增加排除域名列表
   - 检查磁盘I/O性能

3. **分析结果不准确**
   - 更新恶意域名数据库
   - 检查检测规则配置
   - 验证日志格式

### 调试日志

启用详细日志：

```yaml
Log:
  Level: debug
```

查看URL记录器相关日志：

```bash
grep "URL记录器" /var/log/xrayr/error.log
```

## 安全建议

1. **日志文件保护**
   - 设置适当的文件权限
   - 定期备份重要日志
   - 考虑日志加密

2. **恶意域名数据库**
   - 定期更新恶意域名列表
   - 使用可信的威胁情报源
   - 建立白名单机制

3. **监控和告警**
   - 设置恶意访问告警
   - 监控可疑用户行为
   - 建立自动化响应机制

## 更新记录

- **v1.0.0** (2024-07-14)
  - 首次发布URL访问记录器功能
  - 支持基本的URL记录和分析
  - 内置恶意域名检测规则

## 参与贡献

如果您发现问题或有改进建议，请：

1. 提交Issue到GitHub仓库
2. 提供详细的复现步骤
3. 包含相关的日志信息
4. 建议改进方案

---

**注意**：该功能仅用于网络安全防护目的，请确保遵守相关法律法规，尊重用户隐私。 