#!/bin/bash

# 实时推送功能测试脚本

echo "=========================================="
echo "XrayR URL访问实时推送功能测试"
echo "=========================================="

# 创建测试配置文件
cat > /tmp/xrayr_realtime_test.yml << EOF
Log:
  Level: info

Nodes:
  - PanelType: "NewV2board"
    ApiConfig:
      ApiHost: "https://test-panel.com"
      ApiKey: "test-key"
      NodeID: 1
      NodeType: V2ray
    ControllerConfig:
      UpdatePeriodic: 60
      URLLoggerConfig:
        Enable: true
        LogPath: "/tmp/xrayr_url_access.log"
        EnableRealtime: true
        RealtimeAddr: "127.0.0.1:9999"
        FlushInterval: 5
        EnableDomainLog: true
        EnableFullURL: true
EOF

echo "配置文件已创建"

# 使用netcat测试TCP连接
echo ""
echo "测试实时推送功能..."
echo "使用以下命令连接到实时推送服务器："
echo ""
echo "  nc localhost 9999"
echo ""
echo "或使用Python客户端："
echo ""
echo "  python3 examples/realtime_client.py"
echo ""
echo "启动XrayR后，当有用户访问网站时，你将实时看到访问记录。"
echo ""
echo "示例输出："
echo '{"type":"welcome","message":"XrayR URL实时推送服务","time":"2024-07-14T12:00:00Z"}'
echo '{"type":"url_access","data":{"timestamp":"2024-07-14T12:00:15Z","user_id":0,"email":"user@example.com","domain":"google.com","full_url":"https://google.com:443","protocol":"https","node_id":1,"node_tag":"node1","source_ip":"192.168.1.100","user_info":"level:0,tag:node1,network:tcp","request_time":"2024-07-14 12:00:15"}}'
echo ""
echo "配置文件路径: /tmp/xrayr_realtime_test.yml"
echo "使用方法: ./xrayr -c /tmp/xrayr_realtime_test.yml" 