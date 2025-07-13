package cmd

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(statusCmd)
}

var statusCmd = &cobra.Command{
	Use:   "status",
	Short: "显示XrayR服务状态和管理选项",
	Long: `显示XrayR服务的当前状态，并提供基本的管理功能。

该命令可以：
- 显示服务运行状态
- 提供启动/停止/重启选项
- 查看日志
- 监控URL记录器状态`,
	Run: func(cmd *cobra.Command, args []string) {
		showStatusAndMenu()
	},
}

func showStatusAndMenu() {
	for {
		// 清屏
		fmt.Print("\033[2J\033[H")

		fmt.Println(strings.Repeat("=", 50))
		fmt.Println("        XrayR URL Logger 管理面板")
		fmt.Println(strings.Repeat("=", 50))
		fmt.Println()

		// 显示服务状态
		showServiceStatus()
		fmt.Println()

		// 显示URL记录器状态
		showURLLoggerStatus()
		fmt.Println()

		// 显示菜单
		fmt.Println("📋 管理选项:")
		fmt.Println("  1. 启动服务")
		fmt.Println("  2. 停止服务")
		fmt.Println("  3. 重启服务")
		fmt.Println("  4. 查看实时日志")
		fmt.Println("  5. 查看URL访问日志")
		fmt.Println("  6. 监控实时数据")
		fmt.Println("  7. 服务配置信息")
		fmt.Println("  0. 退出")
		fmt.Println()

		fmt.Print("请选择操作 [0-7]: ")
		reader := bufio.NewReader(os.Stdin)
		choice, _ := reader.ReadString('\n')
		choice = strings.TrimSpace(choice)

		switch choice {
		case "1":
			startService()
		case "2":
			stopService()
		case "3":
			restartService()
		case "4":
			viewLogs()
		case "5":
			viewURLLogs()
		case "6":
			monitorRealtime()
		case "7":
			showConfig()
		case "0":
			fmt.Println("退出管理面板")
			return
		default:
			fmt.Println("无效选择，请重试...")
			fmt.Print("按 Enter 继续...")
			reader.ReadString('\n')
		}
	}
}

func showServiceStatus() {
	fmt.Println("🔍 服务状态:")

	// 检查systemd服务状态
	cmd := exec.Command("systemctl", "is-active", "xrayr")
	output, err := cmd.Output()
	status := strings.TrimSpace(string(output))

	if err != nil || status != "active" {
		fmt.Println("  ❌ XrayR服务: 未运行")
	} else {
		fmt.Println("  ✅ XrayR服务: 正在运行")

		// 获取进程信息
		cmd = exec.Command("systemctl", "show", "xrayr", "--property=MainPID")
		output, err = cmd.Output()
		if err == nil {
			pidStr := strings.TrimSpace(strings.Split(string(output), "=")[1])
			if pid, err := strconv.Atoi(pidStr); err == nil && pid > 0 {
				fmt.Printf("  📍 进程ID: %d\n", pid)
			}
		}

		// 获取启动时间
		cmd = exec.Command("systemctl", "show", "xrayr", "--property=ActiveEnterTimestamp")
		output, err = cmd.Output()
		if err == nil {
			timestamp := strings.TrimSpace(strings.Split(string(output), "=")[1])
			if timestamp != "" {
				fmt.Printf("  ⏰ 启动时间: %s\n", timestamp)
			}
		}
	}
}

func showURLLoggerStatus() {
	fmt.Println("📊 URL记录器状态:")

	// 检查日志文件
	logPath := "/var/log/xrayr/url_access.log"
	if _, err := os.Stat(logPath); err == nil {
		fmt.Printf("  ✅ URL日志文件: %s\n", logPath)

		// 获取文件大小
		if stat, err := os.Stat(logPath); err == nil {
			size := stat.Size()
			if size > 1024*1024 {
				fmt.Printf("  📏 文件大小: %.2f MB\n", float64(size)/(1024*1024))
			} else {
				fmt.Printf("  📏 文件大小: %d KB\n", size/1024)
			}
		}
	} else {
		fmt.Printf("  ❌ URL日志文件: 不存在\n")
	}

	// 检查实时推送端口
	cmd := exec.Command("lsof", "-i", ":9999")
	if err := cmd.Run(); err == nil {
		fmt.Println("  ✅ 实时推送服务: 端口9999正在监听")
	} else {
		fmt.Println("  ❌ 实时推送服务: 端口9999未监听")
	}
}

func startService() {
	fmt.Println("🚀 启动XrayR服务...")
	cmd := exec.Command("systemctl", "start", "xrayr")
	if err := cmd.Run(); err != nil {
		fmt.Printf("❌ 启动失败: %v\n", err)
	} else {
		fmt.Println("✅ 服务启动成功")
	}

	fmt.Print("按 Enter 继续...")
	bufio.NewReader(os.Stdin).ReadString('\n')
}

func stopService() {
	fmt.Println("🛑 停止XrayR服务...")
	cmd := exec.Command("systemctl", "stop", "xrayr")
	if err := cmd.Run(); err != nil {
		fmt.Printf("❌ 停止失败: %v\n", err)
	} else {
		fmt.Println("✅ 服务停止成功")
	}

	fmt.Print("按 Enter 继续...")
	bufio.NewReader(os.Stdin).ReadString('\n')
}

func restartService() {
	fmt.Println("🔄 重启XrayR服务...")
	cmd := exec.Command("systemctl", "restart", "xrayr")
	if err := cmd.Run(); err != nil {
		fmt.Printf("❌ 重启失败: %v\n", err)
	} else {
		fmt.Println("✅ 服务重启成功")
	}

	fmt.Print("按 Enter 继续...")
	bufio.NewReader(os.Stdin).ReadString('\n')
}

func viewLogs() {
	fmt.Println("📋 查看实时日志 (按 Ctrl+C 退出)...")
	fmt.Println()

	cmd := exec.Command("journalctl", "-u", "xrayr", "-f")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Run()
}

func viewURLLogs() {
	fmt.Println("📊 查看URL访问日志 (按 Ctrl+C 退出)...")
	fmt.Println()

	logPath := "/var/log/xrayr/url_access.log"
	if _, err := os.Stat(logPath); err != nil {
		fmt.Printf("❌ 日志文件不存在: %s\n", logPath)
		fmt.Print("按 Enter 继续...")
		bufio.NewReader(os.Stdin).ReadString('\n')
		return
	}

	cmd := exec.Command("tail", "-f", logPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Run()
}

func monitorRealtime() {
	fmt.Println("🔴 监控实时数据推送 (按 Ctrl+C 退出)...")
	fmt.Println()

	cmd := exec.Command("xrayr-monitor")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		fmt.Printf("❌ 监控失败: %v\n", err)
		fmt.Println("请确保实时推送服务已启动")
		fmt.Print("按 Enter 继续...")
		bufio.NewReader(os.Stdin).ReadString('\n')
	}
}

func showConfig() {
	fmt.Println("⚙️ 服务配置信息:")
	fmt.Println()

	// 显示配置文件路径
	fmt.Println("📁 配置文件: /etc/XrayR/config.yml")

	// 尝试读取URL记录器配置
	fmt.Println("📊 URL记录器配置:")
	cmd := exec.Command("grep", "-A", "10", "URLLoggerConfig", "/etc/XrayR/config.yml")
	output, err := cmd.Output()
	if err == nil {
		fmt.Println(string(output))
	} else {
		fmt.Println("  未找到URL记录器配置")
	}

	fmt.Print("按 Enter 继续...")
	bufio.NewReader(os.Stdin).ReadString('\n')
}
