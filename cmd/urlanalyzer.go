package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/XrayR-project/XrayR/common/urllogger"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var (
	logPath     string
	outputPath  string
	maliciousDB string
	showReport  bool
)

func init() {
	urlAnalyzerCmd.Flags().StringVarP(&logPath, "log", "l", "/var/log/xrayr/url_access.log", "URL访问日志文件路径")
	urlAnalyzerCmd.Flags().StringVarP(&outputPath, "output", "o", "", "分析报告输出文件路径 (为空则输出到控制台)")
	urlAnalyzerCmd.Flags().StringVarP(&maliciousDB, "malicious-db", "d", "", "恶意域名数据库文件路径")
	urlAnalyzerCmd.Flags().BoolVarP(&showReport, "report", "r", true, "是否显示详细报告")

	rootCmd.AddCommand(urlAnalyzerCmd)
}

var urlAnalyzerCmd = &cobra.Command{
	Use:   "analyze",
	Short: "分析URL访问日志，检测恶意网站访问",
	Long: `分析URL访问日志文件，检测用户是否访问恶意网站。

该工具可以：
- 分析用户访问的域名
- 检测可疑的恶意域名
- 生成详细的分析报告
- 识别可疑用户行为

示例用法：
  ./xrayr analyze -l /var/log/xrayr/url_access.log -o /tmp/analysis_report.txt
  ./xrayr analyze -l /var/log/xrayr/url_access.log -d /etc/xrayr/malicious_domains.txt`,
	Run: func(cmd *cobra.Command, args []string) {
		if err := runURLAnalyzer(); err != nil {
			log.Fatal(err)
		}
	},
}

func runURLAnalyzer() error {
	// 检查日志文件是否存在
	if _, err := os.Stat(logPath); os.IsNotExist(err) {
		return fmt.Errorf("日志文件不存在: %s", logPath)
	}

	// 创建分析器
	analyzer := urllogger.NewAnalyzer()

	// 如果提供了恶意域名数据库，则加载它
	if maliciousDB != "" {
		if err := analyzer.LoadMaliciousDomains(maliciousDB); err != nil {
			log.WithError(err).Warn("加载恶意域名数据库失败")
		}
	}

	// 分析日志文件
	fmt.Printf("正在分析日志文件: %s\n", logPath)
	result, err := analyzer.AnalyzeLogFile(logPath)
	if err != nil {
		return fmt.Errorf("分析日志文件失败: %v", err)
	}

	// 生成报告
	if showReport {
		report := analyzer.GenerateReport(result)

		if outputPath != "" {
			// 输出到文件
			if err := analyzer.SaveReport(result, outputPath); err != nil {
				return fmt.Errorf("保存报告失败: %v", err)
			}
			fmt.Printf("分析报告已保存到: %s\n", outputPath)
		} else {
			// 输出到控制台
			fmt.Println("\n" + report)
		}
	}

	// 输出统计信息
	fmt.Printf("\n=== 分析统计 ===\n")
	fmt.Printf("总记录数: %d\n", result.TotalRecords)
	fmt.Printf("恶意记录数: %d\n", len(result.MaliciousRecords))
	fmt.Printf("可疑用户数: %d\n", len(result.SuspiciousUsers))
	fmt.Printf("唯一域名数: %d\n", len(result.DomainStats))
	fmt.Printf("分析时间: %s\n", result.AnalyzedAt.Format("2006-01-02 15:04:05"))

	// 如果发现恶意访问，返回非零退出码
	if len(result.MaliciousRecords) > 0 {
		fmt.Printf("\n⚠️  发现 %d 条恶意访问记录！\n", len(result.MaliciousRecords))
		return nil // 不返回错误，只是提示
	}

	fmt.Println("\n✅ 未发现恶意访问记录")
	return nil
}

// 添加一个创建示例恶意域名数据库的命令
var createMaliciousDBCmd = &cobra.Command{
	Use:   "create-malicious-db",
	Short: "创建示例恶意域名数据库",
	Long: `创建一个示例恶意域名数据库文件，用于URL访问分析。

该文件包含一些常见的恶意域名示例，可以根据实际需要进行修改。`,
	Run: func(cmd *cobra.Command, args []string) {
		dbPath := "/tmp/malicious_domains.txt"
		if len(args) > 0 {
			dbPath = args[0]
		}

		if err := createSampleMaliciousDB(dbPath); err != nil {
			log.Fatal(err)
		}

		fmt.Printf("示例恶意域名数据库已创建: %s\n", dbPath)
	},
}

func init() {
	rootCmd.AddCommand(createMaliciousDBCmd)
}

func createSampleMaliciousDB(dbPath string) error {
	// 创建目录
	if err := os.MkdirAll(filepath.Dir(dbPath), 0755); err != nil {
		return fmt.Errorf("创建目录失败: %v", err)
	}

	// 示例恶意域名列表
	maliciousDomains := []string{
		"# 恶意域名数据库示例",
		"# 以 # 开头的行为注释",
		"# 每行一个域名",
		"",
		"# 恶意软件域名",
		"malware.example.com",
		"virus.test.com",
		"trojan.bad.com",
		"botnet.evil.com",
		"",
		"# 钓鱼网站",
		"phishing.fake.com",
		"fake-bank.scam.com",
		"login-secure.phish.com",
		"",
		"# 可疑域名",
		"suspicious.tk",
		"bad.ml",
		"evil.ga",
		"",
		"# 已知恶意域名（示例）",
		"badsite.com",
		"maliciousdomain.net",
		"evilwebsite.org",
	}

	// 写入文件
	file, err := os.Create(dbPath)
	if err != nil {
		return fmt.Errorf("创建文件失败: %v", err)
	}
	defer file.Close()

	for _, domain := range maliciousDomains {
		if _, err := file.WriteString(domain + "\n"); err != nil {
			return fmt.Errorf("写入文件失败: %v", err)
		}
	}

	return nil
}
