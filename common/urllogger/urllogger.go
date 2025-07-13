// Package urllogger 用于记录用户访问的URL地址
package urllogger

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/XrayR-project/XrayR/api"
	log "github.com/sirupsen/logrus"
)

// URLRecord 表示一条URL访问记录
type URLRecord struct {
	Timestamp   time.Time `json:"timestamp"`
	UserID      int       `json:"user_id"`
	Email       string    `json:"email"`
	Domain      string    `json:"domain"`
	FullURL     string    `json:"full_url"`
	Protocol    string    `json:"protocol"`
	NodeID      int       `json:"node_id"`
	NodeTag     string    `json:"node_tag"`
	SourceIP    string    `json:"source_ip"`    // 用户源IP
	UserInfo    string    `json:"user_info"`    // 额外用户信息
	RequestTime string    `json:"request_time"` // 格式化时间
}

// Config URL记录器配置
type Config struct {
	Enable          bool     `mapstructure:"Enable"`
	LogPath         string   `mapstructure:"LogPath"`
	MaxFileSize     int64    `mapstructure:"MaxFileSize"`     // MB
	MaxFileCount    int      `mapstructure:"MaxFileCount"`    // 最多保留的文件数
	FlushInterval   int      `mapstructure:"FlushInterval"`   // 刷新间隔（秒）
	EnableDomainLog bool     `mapstructure:"EnableDomainLog"` // 是否记录域名访问
	EnableFullURL   bool     `mapstructure:"EnableFullURL"`   // 是否记录完整URL
	ExcludeDomains  []string `mapstructure:"ExcludeDomains"`  // 排除的域名列表
	// 实时推送配置
	EnableRealtime bool   `mapstructure:"EnableRealtime"` // 是否启用实时推送
	RealtimeAddr   string `mapstructure:"RealtimeAddr"`   // 实时推送监听地址，如 "127.0.0.1:9999"
}

// URLLogger URL记录器
type URLLogger struct {
	config      *Config
	logFile     *os.File
	buffer      []URLRecord
	bufferMutex sync.RWMutex
	nodeID      int
	apiClient   api.API
	running     bool
	stopChan    chan struct{}
	// 实时推送服务器
	realtimeServer *RealtimeServer
}

// New 创建新的URL记录器实例
func New(config *Config, nodeID int, apiClient api.API) *URLLogger {
	if config == nil {
		config = &Config{
			Enable:          false,
			LogPath:         "/var/log/xrayr/url_access.log",
			MaxFileSize:     100, // 100MB
			MaxFileCount:    10,
			FlushInterval:   10,
			EnableDomainLog: true,
			EnableFullURL:   false,
			ExcludeDomains:  []string{},
			EnableRealtime:  false,
			RealtimeAddr:    "127.0.0.1:9999",
		}
	}

	logger := &URLLogger{
		config:    config,
		buffer:    make([]URLRecord, 0),
		nodeID:    nodeID,
		apiClient: apiClient,
		stopChan:  make(chan struct{}),
	}

	// 如果启用实时推送，创建实时服务器
	if config.EnableRealtime && config.RealtimeAddr != "" {
		logger.realtimeServer = NewRealtimeServer(config.RealtimeAddr)
	}

	return logger
}

// Start 启动URL记录器
func (ul *URLLogger) Start() error {
	if !ul.config.Enable {
		return nil
	}

	// 如果LogPath不为空，才创建日志文件
	if ul.config.LogPath != "" {
		// 创建日志目录
		logDir := filepath.Dir(ul.config.LogPath)
		if err := os.MkdirAll(logDir, 0755); err != nil {
			return fmt.Errorf("创建日志目录失败: %v", err)
		}

		// 打开日志文件
		var err error
		ul.logFile, err = os.OpenFile(ul.config.LogPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			return fmt.Errorf("打开日志文件失败: %v", err)
		}
		log.WithField("path", ul.config.LogPath).Info("URL日志文件已创建")
	} else {
		log.Info("URL记录器运行在纯实时推送模式（不保存文件）")
	}

	// 启动实时推送服务器
	if ul.realtimeServer != nil {
		if err := ul.realtimeServer.Start(); err != nil {
			log.WithError(err).Error("启动实时推送服务器失败")
			// 不影响主功能
		}
	}

	ul.running = true

	// 只有在需要文件记录时才启动flush routine
	if ul.logFile != nil {
		go ul.flushRoutine()
	}

	log.WithFields(log.Fields{
		"path":          ul.config.LogPath,
		"node_id":       ul.nodeID,
		"interval":      ul.config.FlushInterval,
		"realtime":      ul.config.EnableRealtime,
		"realtime_addr": ul.config.RealtimeAddr,
		"file_mode":     ul.logFile != nil,
	}).Info("URL记录器启动成功")

	return nil
}

// Stop 停止URL记录器
func (ul *URLLogger) Stop() error {
	if !ul.running {
		return nil
	}

	close(ul.stopChan)
	ul.running = false

	// 刷新剩余的缓冲区
	ul.flush()

	// 关闭日志文件
	if ul.logFile != nil {
		ul.logFile.Close()
	}

	// 停止实时推送服务器
	if ul.realtimeServer != nil {
		ul.realtimeServer.Stop()
	}

	log.Info("URL记录器已停止")
	return nil
}

// LogURL 记录URL访问（增加用户源IP和额外信息参数）
func (ul *URLLogger) LogURL(ctx context.Context, userID int, email string, domain string, fullURL string, protocol string, nodeTag string, sourceIP string, extraInfo string) {
	if !ul.config.Enable {
		return
	}

	// 检查是否在排除列表中
	for _, excludeDomain := range ul.config.ExcludeDomains {
		if domain == excludeDomain {
			return
		}
	}

	timestamp := time.Now()
	record := URLRecord{
		Timestamp:   timestamp,
		UserID:      userID,
		Email:       email,
		Domain:      domain,
		Protocol:    protocol,
		NodeID:      ul.nodeID,
		NodeTag:     nodeTag,
		SourceIP:    sourceIP,
		UserInfo:    extraInfo,
		RequestTime: timestamp.Format("2006-01-02 15:04:05"),
	}

	// 根据配置决定是否记录完整URL
	if ul.config.EnableFullURL {
		record.FullURL = fullURL
	}

	// 如果启用了文件记录，添加到缓冲区
	if ul.logFile != nil {
		ul.bufferMutex.Lock()
		ul.buffer = append(ul.buffer, record)
		ul.bufferMutex.Unlock()
	}

	// 实时推送（始终执行，这是核心功能）
	if ul.realtimeServer != nil && ul.realtimeServer.IsEnabled() {
		realtimeRecord := &RealtimeRecord{
			Timestamp:   record.Timestamp,
			UserID:      record.UserID,
			Email:       record.Email,
			Domain:      record.Domain,
			FullURL:     fullURL, // 实时推送总是包含完整URL
			Protocol:    record.Protocol,
			NodeID:      record.NodeID,
			NodeTag:     record.NodeTag,
			SourceIP:    record.SourceIP,
			UserInfo:    record.UserInfo,
			RequestTime: record.RequestTime,
		}
		ul.realtimeServer.PushRecord(realtimeRecord)
	}
}

// flush 刷新缓冲区到文件
func (ul *URLLogger) flush() {
	ul.bufferMutex.Lock()
	defer ul.bufferMutex.Unlock()

	if len(ul.buffer) == 0 {
		return
	}

	// 如果启用了文件记录，写入文件
	if ul.logFile != nil {
		for _, record := range ul.buffer {
			jsonData, err := json.Marshal(record)
			if err != nil {
				log.WithError(err).Error("序列化URL记录失败")
				continue
			}

			if _, err := ul.logFile.WriteString(string(jsonData) + "\n"); err != nil {
				log.WithError(err).Error("写入URL记录文件失败")
				continue
			}
		}
		ul.logFile.Sync()
		log.WithField("count", len(ul.buffer)).Debug("URL记录已写入文件")
	}

	// 发送到面板API（如果支持）
	if ul.apiClient != nil {
		ul.sendToPanel(ul.buffer)
	}

	// 清空缓冲区
	ul.buffer = ul.buffer[:0]
}

// flushRoutine 定期刷新缓冲区
func (ul *URLLogger) flushRoutine() {
	ticker := time.NewTicker(time.Duration(ul.config.FlushInterval) * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			ul.flush()
			ul.rotateLogFile()
		case <-ul.stopChan:
			return
		}
	}
}

// rotateLogFile 轮转日志文件
func (ul *URLLogger) rotateLogFile() {
	if ul.logFile == nil {
		return
	}

	// 检查文件大小
	if fileInfo, err := ul.logFile.Stat(); err == nil {
		if fileInfo.Size() > ul.config.MaxFileSize*1024*1024 {
			// 关闭当前文件
			ul.logFile.Close()

			// 轮转文件
			baseName := ul.config.LogPath
			for i := ul.config.MaxFileCount - 1; i > 0; i-- {
				oldName := fmt.Sprintf("%s.%d", baseName, i)
				newName := fmt.Sprintf("%s.%d", baseName, i+1)
				os.Rename(oldName, newName)
			}

			// 将当前文件重命名为 .1
			os.Rename(baseName, baseName+".1")

			// 创建新的文件
			var err error
			ul.logFile, err = os.OpenFile(baseName, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
			if err != nil {
				log.WithError(err).Error("创建新的日志文件失败")
			}
		}
	}
}

// sendToPanel 发送URL记录到面板
func (ul *URLLogger) sendToPanel(records []URLRecord) {
	// 这里可以根据不同的面板类型实现不同的发送逻辑
	// 目前先记录到日志，后续可以扩展为实际的API调用
	log.WithField("count", len(records)).Debug("发送URL记录到面板")
}

// GetConfig 获取默认配置
func GetDefaultConfig() *Config {
	return &Config{
		Enable:          false,
		LogPath:         "/var/log/xrayr/url_access.log",
		MaxFileSize:     100,
		MaxFileCount:    10,
		FlushInterval:   10,
		EnableDomainLog: true,
		EnableFullURL:   false,
		ExcludeDomains:  []string{},
		EnableRealtime:  false,
		RealtimeAddr:    "127.0.0.1:9999",
	}
}
