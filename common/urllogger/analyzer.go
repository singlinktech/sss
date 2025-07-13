// Package urllogger 的分析器模块
package urllogger

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"

	log "github.com/sirupsen/logrus"
)

// MaliciousRecord 恶意访问记录
type MaliciousRecord struct {
	URLRecord
	Reason     string    `json:"reason"`      // 检测原因
	Severity   string    `json:"severity"`    // 严重程度: low, medium, high
	DetectedAt time.Time `json:"detected_at"` // 检测时间
	RuleID     string    `json:"rule_id"`     // 触发的规则ID
}

// AnalysisResult 分析结果
type AnalysisResult struct {
	TotalRecords     int               `json:"total_records"`
	MaliciousRecords []MaliciousRecord `json:"malicious_records"`
	UserStats        map[string]int    `json:"user_stats"`       // 用户访问统计
	DomainStats      map[string]int    `json:"domain_stats"`     // 域名访问统计
	SuspiciousUsers  []string          `json:"suspicious_users"` // 可疑用户列表
	TopDomains       []string          `json:"top_domains"`      // 热门域名
	AnalyzedAt       time.Time         `json:"analyzed_at"`      // 分析时间
}

// MaliciousRule 恶意检测规则
type MaliciousRule struct {
	ID          string         `json:"id"`
	Name        string         `json:"name"`
	Description string         `json:"description"`
	Pattern     *regexp.Regexp `json:"-"`
	PatternStr  string         `json:"pattern"`
	Severity    string         `json:"severity"`
	Enabled     bool           `json:"enabled"`
}

// Analyzer URL访问分析器
type Analyzer struct {
	maliciousRules     []MaliciousRule
	maliciousDomains   map[string]bool
	suspiciousPatterns []*regexp.Regexp
}

// NewAnalyzer 创建新的分析器实例
func NewAnalyzer() *Analyzer {
	analyzer := &Analyzer{
		maliciousRules:     []MaliciousRule{},
		maliciousDomains:   make(map[string]bool),
		suspiciousPatterns: []*regexp.Regexp{},
	}

	// 加载默认规则
	analyzer.loadDefaultRules()

	return analyzer
}

// loadDefaultRules 加载默认的恶意检测规则
func (a *Analyzer) loadDefaultRules() {
	// 添加一些常见的恶意域名检测规则
	defaultRules := []MaliciousRule{
		{
			ID:          "malware_domain",
			Name:        "恶意软件域名",
			Description: "检测已知的恶意软件域名",
			PatternStr:  `(malware|virus|trojan|botnet|phishing)\..*`,
			Severity:    "high",
			Enabled:     true,
		},
		{
			ID:          "suspicious_tld",
			Name:        "可疑顶级域名",
			Description: "检测可疑的顶级域名",
			PatternStr:  `.*\.(tk|ml|ga|cf|gq)$`,
			Severity:    "medium",
			Enabled:     true,
		},
		{
			ID:          "tor_exit_node",
			Name:        "Tor出口节点",
			Description: "检测Tor网络出口节点",
			PatternStr:  `.*\.onion$`,
			Severity:    "medium",
			Enabled:     true,
		},
		{
			ID:          "suspicious_subdomain",
			Name:        "可疑子域名",
			Description: "检测可疑的子域名模式",
			PatternStr:  `(admin|login|secure|bank|pay|account)\..*\.(tk|ml|ga|cf|gq)$`,
			Severity:    "high",
			Enabled:     true,
		},
		{
			ID:          "dga_domain",
			Name:        "DGA域名",
			Description: "检测可能的域名生成算法(DGA)产生的域名",
			PatternStr:  `[a-z]{8,20}\.(com|net|org|info|biz)$`,
			Severity:    "medium",
			Enabled:     true,
		},
	}

	// 编译正则表达式
	for _, rule := range defaultRules {
		if compiled, err := regexp.Compile(rule.PatternStr); err == nil {
			rule.Pattern = compiled
			a.maliciousRules = append(a.maliciousRules, rule)
		} else {
			log.WithError(err).WithField("rule", rule.ID).Error("编译恶意检测规则失败")
		}
	}
}

// LoadMaliciousDomains 从文件加载恶意域名列表
func (a *Analyzer) LoadMaliciousDomains(filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("打开恶意域名文件失败: %v", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	count := 0
	for scanner.Scan() {
		domain := strings.TrimSpace(scanner.Text())
		if domain != "" && !strings.HasPrefix(domain, "#") {
			a.maliciousDomains[domain] = true
			count++
		}
	}

	if err := scanner.Err(); err != nil {
		return fmt.Errorf("读取恶意域名文件失败: %v", err)
	}

	log.WithField("count", count).Info("加载恶意域名列表完成")
	return nil
}

// AddCustomRule 添加自定义检测规则
func (a *Analyzer) AddCustomRule(rule MaliciousRule) error {
	compiled, err := regexp.Compile(rule.PatternStr)
	if err != nil {
		return fmt.Errorf("编译规则失败: %v", err)
	}

	rule.Pattern = compiled
	a.maliciousRules = append(a.maliciousRules, rule)
	return nil
}

// AnalyzeLogFile 分析日志文件
func (a *Analyzer) AnalyzeLogFile(logPath string) (*AnalysisResult, error) {
	file, err := os.Open(logPath)
	if err != nil {
		return nil, fmt.Errorf("打开日志文件失败: %v", err)
	}
	defer file.Close()

	result := &AnalysisResult{
		UserStats:   make(map[string]int),
		DomainStats: make(map[string]int),
		AnalyzedAt:  time.Now(),
	}

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		var record URLRecord
		if err := json.Unmarshal([]byte(line), &record); err != nil {
			log.WithError(err).Debug("解析URL记录失败")
			continue
		}

		result.TotalRecords++

		// 统计用户访问
		userKey := fmt.Sprintf("%s(%d)", record.Email, record.UserID)
		result.UserStats[userKey]++

		// 统计域名访问
		result.DomainStats[record.Domain]++

		// 检测是否为恶意访问
		if maliciousRecord := a.checkMalicious(record); maliciousRecord != nil {
			result.MaliciousRecords = append(result.MaliciousRecords, *maliciousRecord)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("读取日志文件失败: %v", err)
	}

	// 分析可疑用户
	result.SuspiciousUsers = a.findSuspiciousUsers(result.UserStats, result.MaliciousRecords)

	// 获取热门域名
	result.TopDomains = a.getTopDomains(result.DomainStats, 20)

	return result, nil
}

// checkMalicious 检查是否为恶意访问
func (a *Analyzer) checkMalicious(record URLRecord) *MaliciousRecord {
	// 检查恶意域名列表
	if a.maliciousDomains[record.Domain] {
		return &MaliciousRecord{
			URLRecord:  record,
			Reason:     "域名在恶意域名列表中",
			Severity:   "high",
			DetectedAt: time.Now(),
			RuleID:     "malicious_domain_list",
		}
	}

	// 检查规则匹配
	for _, rule := range a.maliciousRules {
		if !rule.Enabled {
			continue
		}

		if rule.Pattern.MatchString(record.Domain) {
			return &MaliciousRecord{
				URLRecord:  record,
				Reason:     rule.Description,
				Severity:   rule.Severity,
				DetectedAt: time.Now(),
				RuleID:     rule.ID,
			}
		}
	}

	return nil
}

// findSuspiciousUsers 查找可疑用户
func (a *Analyzer) findSuspiciousUsers(userStats map[string]int, maliciousRecords []MaliciousRecord) []string {
	suspiciousUsers := make([]string, 0)
	userMaliciousCount := make(map[string]int)

	// 统计每个用户的恶意访问次数
	for _, record := range maliciousRecords {
		userKey := fmt.Sprintf("%s(%d)", record.Email, record.UserID)
		userMaliciousCount[userKey]++
	}

	// 找出恶意访问次数超过阈值的用户
	for user, count := range userMaliciousCount {
		if count >= 5 { // 阈值：5次恶意访问
			suspiciousUsers = append(suspiciousUsers, user)
		}
	}

	return suspiciousUsers
}

// getTopDomains 获取访问量最高的域名
func (a *Analyzer) getTopDomains(domainStats map[string]int, limit int) []string {
	type domainCount struct {
		domain string
		count  int
	}

	domains := make([]domainCount, 0, len(domainStats))
	for domain, count := range domainStats {
		domains = append(domains, domainCount{domain, count})
	}

	// 简单排序（冒泡排序）
	for i := 0; i < len(domains)-1; i++ {
		for j := 0; j < len(domains)-1-i; j++ {
			if domains[j].count < domains[j+1].count {
				domains[j], domains[j+1] = domains[j+1], domains[j]
			}
		}
	}

	result := make([]string, 0, limit)
	for i := 0; i < len(domains) && i < limit; i++ {
		result = append(result, domains[i].domain)
	}

	return result
}

// GenerateReport 生成分析报告
func (a *Analyzer) GenerateReport(result *AnalysisResult) string {
	report := fmt.Sprintf("URL访问分析报告\n")
	report += fmt.Sprintf("================\n")
	report += fmt.Sprintf("分析时间: %s\n", result.AnalyzedAt.Format("2006-01-02 15:04:05"))
	report += fmt.Sprintf("总记录数: %d\n", result.TotalRecords)
	report += fmt.Sprintf("恶意记录数: %d\n", len(result.MaliciousRecords))
	report += fmt.Sprintf("可疑用户数: %d\n", len(result.SuspiciousUsers))
	report += fmt.Sprintf("\n")

	if len(result.MaliciousRecords) > 0 {
		report += fmt.Sprintf("恶意访问记录:\n")
		report += fmt.Sprintf("-------------\n")
		for _, record := range result.MaliciousRecords {
			report += fmt.Sprintf("时间: %s | 用户: %s | 域名: %s | 原因: %s | 严重程度: %s\n",
				record.Timestamp.Format("2006-01-02 15:04:05"),
				record.Email,
				record.Domain,
				record.Reason,
				record.Severity)
		}
		report += fmt.Sprintf("\n")
	}

	if len(result.SuspiciousUsers) > 0 {
		report += fmt.Sprintf("可疑用户:\n")
		report += fmt.Sprintf("--------\n")
		for _, user := range result.SuspiciousUsers {
			report += fmt.Sprintf("- %s\n", user)
		}
		report += fmt.Sprintf("\n")
	}

	if len(result.TopDomains) > 0 {
		report += fmt.Sprintf("热门域名:\n")
		report += fmt.Sprintf("--------\n")
		for i, domain := range result.TopDomains {
			if i >= 10 { // 只显示前10个
				break
			}
			report += fmt.Sprintf("%d. %s (访问次数: %d)\n", i+1, domain, result.DomainStats[domain])
		}
	}

	return report
}

// SaveReport 保存分析报告到文件
func (a *Analyzer) SaveReport(result *AnalysisResult, reportPath string) error {
	report := a.GenerateReport(result)

	if err := os.WriteFile(reportPath, []byte(report), 0644); err != nil {
		return fmt.Errorf("保存报告失败: %v", err)
	}

	log.WithField("path", reportPath).Info("分析报告已保存")
	return nil
}
