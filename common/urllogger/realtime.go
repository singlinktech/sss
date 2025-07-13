// Package urllogger 的实时推送模块
package urllogger

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"sync"
	"time"

	log "github.com/sirupsen/logrus"
)

// RealtimeServer TCP实时推送服务器
type RealtimeServer struct {
	enabled    bool
	listenAddr string
	listener   net.Listener
	clients    map[net.Conn]bool
	clientsMux sync.RWMutex
	msgChan    chan []byte
	ctx        context.Context
	cancel     context.CancelFunc
	wg         sync.WaitGroup
}

// RealtimeRecord 实时推送的记录格式（包含完整用户信息）
type RealtimeRecord struct {
	Timestamp   time.Time `json:"timestamp"`
	UserID      int       `json:"user_id"`
	Email       string    `json:"email"`
	Domain      string    `json:"domain"`
	FullURL     string    `json:"full_url"`
	Protocol    string    `json:"protocol"`
	NodeID      int       `json:"node_id"`
	NodeTag     string    `json:"node_tag"`
	SourceIP    string    `json:"source_ip"`    // 用户源IP
	UserInfo    string    `json:"user_info"`    // 额外的用户信息
	RequestTime string    `json:"request_time"` // 请求时间字符串
}

// NewRealtimeServer 创建实时推送服务器
func NewRealtimeServer(listenAddr string) *RealtimeServer {
	ctx, cancel := context.WithCancel(context.Background())
	return &RealtimeServer{
		enabled:    true,
		listenAddr: listenAddr,
		clients:    make(map[net.Conn]bool),
		msgChan:    make(chan []byte, 100), // 缓冲区
		ctx:        ctx,
		cancel:     cancel,
	}
}

// Start 启动实时推送服务器
func (rs *RealtimeServer) Start() error {
	if !rs.enabled || rs.listenAddr == "" {
		return nil
	}

	var err error
	rs.listener, err = net.Listen("tcp", rs.listenAddr)
	if err != nil {
		return fmt.Errorf("启动TCP监听失败: %v", err)
	}

	log.WithField("address", rs.listenAddr).Info("实时推送服务器已启动")

	// 启动接受连接的goroutine
	rs.wg.Add(1)
	go rs.acceptConnections()

	// 启动消息分发的goroutine
	rs.wg.Add(1)
	go rs.broadcastMessages()

	return nil
}

// Stop 停止实时推送服务器
func (rs *RealtimeServer) Stop() error {
	if rs.cancel != nil {
		rs.cancel()
	}

	if rs.listener != nil {
		rs.listener.Close()
	}

	// 关闭所有客户端连接
	rs.clientsMux.Lock()
	for conn := range rs.clients {
		conn.Close()
	}
	rs.clients = make(map[net.Conn]bool)
	rs.clientsMux.Unlock()

	// 等待所有goroutine结束
	rs.wg.Wait()

	close(rs.msgChan)

	log.Info("实时推送服务器已停止")
	return nil
}

// acceptConnections 接受客户端连接
func (rs *RealtimeServer) acceptConnections() {
	defer rs.wg.Done()

	for {
		conn, err := rs.listener.Accept()
		if err != nil {
			select {
			case <-rs.ctx.Done():
				return
			default:
				log.WithError(err).Error("接受连接失败")
				continue
			}
		}

		// 添加新客户端
		rs.clientsMux.Lock()
		rs.clients[conn] = true
		rs.clientsMux.Unlock()

		log.WithField("remote", conn.RemoteAddr()).Info("新客户端连接")

		// 发送欢迎消息
		welcome := map[string]string{
			"type":    "welcome",
			"message": "XrayR URL实时推送服务",
			"time":    time.Now().Format(time.RFC3339),
		}
		if data, err := json.Marshal(welcome); err == nil {
			conn.Write(append(data, '\n'))
		}

		// 启动心跳检测
		go rs.handleClient(conn)
	}
}

// handleClient 处理客户端连接
func (rs *RealtimeServer) handleClient(conn net.Conn) {
	defer func() {
		rs.clientsMux.Lock()
		delete(rs.clients, conn)
		rs.clientsMux.Unlock()
		conn.Close()
		log.WithField("remote", conn.RemoteAddr()).Info("客户端断开连接")
	}()

	// 设置心跳
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-rs.ctx.Done():
			return
		case <-ticker.C:
			// 发送心跳
			heartbeat := map[string]string{
				"type": "heartbeat",
				"time": time.Now().Format(time.RFC3339),
			}
			if data, err := json.Marshal(heartbeat); err == nil {
				if _, err := conn.Write(append(data, '\n')); err != nil {
					return // 连接已断开
				}
			}
		}
	}
}

// broadcastMessages 广播消息给所有客户端
func (rs *RealtimeServer) broadcastMessages() {
	defer rs.wg.Done()

	for {
		select {
		case <-rs.ctx.Done():
			return
		case msg := <-rs.msgChan:
			rs.clientsMux.RLock()
			clients := make([]net.Conn, 0, len(rs.clients))
			for conn := range rs.clients {
				clients = append(clients, conn)
			}
			rs.clientsMux.RUnlock()

			// 发送给所有客户端
			for _, conn := range clients {
				if _, err := conn.Write(append(msg, '\n')); err != nil {
					// 客户端断开，会在handleClient中处理
					log.WithError(err).Debug("发送消息失败")
				}
			}
		}
	}
}

// PushRecord 推送访问记录
func (rs *RealtimeServer) PushRecord(record *RealtimeRecord) {
	if !rs.enabled || rs.listener == nil {
		return
	}

	// 转换为JSON
	data, err := json.Marshal(map[string]interface{}{
		"type": "url_access",
		"data": record,
	})
	if err != nil {
		log.WithError(err).Error("序列化实时记录失败")
		return
	}

	// 非阻塞发送
	select {
	case rs.msgChan <- data:
		// 成功发送到通道
	default:
		// 通道满了，丢弃消息（避免阻塞）
		log.Warn("实时推送通道已满，丢弃消息")
	}
}

// IsEnabled 检查是否启用
func (rs *RealtimeServer) IsEnabled() bool {
	return rs.enabled && rs.listener != nil
}

// GetConnectedClients 获取连接的客户端数量
func (rs *RealtimeServer) GetConnectedClients() int {
	rs.clientsMux.RLock()
	defer rs.clientsMux.RUnlock()
	return len(rs.clients)
}
