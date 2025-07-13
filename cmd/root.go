package cmd

import (
	"fmt"
	"os"
	"os/signal"
	"path"
	"runtime"
	"strings"
	"syscall"
	"time"

	log "github.com/sirupsen/logrus"

	"github.com/fsnotify/fsnotify"
	"github.com/spf13/cobra"
	"github.com/spf13/viper"

	"github.com/XrayR-project/XrayR/panel"
)

var (
	cfgFile string
	rootCmd = &cobra.Command{
		Use: "XrayR",
		Run: func(cmd *cobra.Command, args []string) {
			// 如果没有配置文件参数，显示帮助信息
			if cfgFile == "" {
				// 检查默认配置文件是否存在
				if _, err := os.Stat("config.yml"); os.IsNotExist(err) {
					showHelpWithoutConfig()
					return
				}
			}

			if err := run(); err != nil {
				log.Fatal(err)
			}
		},
	}
)

func init() {
	rootCmd.PersistentFlags().StringVarP(&cfgFile, "config", "c", "", "Config file for XrayR.")
}

func getConfig() (*viper.Viper, error) {
	config := viper.New()

	// Set custom path and name
	if cfgFile != "" {
		configName := path.Base(cfgFile)
		configFileExt := path.Ext(cfgFile)
		configNameOnly := strings.TrimSuffix(configName, configFileExt)
		configPath := path.Dir(cfgFile)
		config.SetConfigName(configNameOnly)
		config.SetConfigType(strings.TrimPrefix(configFileExt, "."))
		config.AddConfigPath(configPath)
		// Set ASSET Path and Config Path for XrayR
		os.Setenv("XRAY_LOCATION_ASSET", configPath)
		os.Setenv("XRAY_LOCATION_CONFIG", configPath)
	} else {
		// Set default config path
		config.SetConfigName("config")
		config.SetConfigType("yml")
		config.AddConfigPath(".")

	}

	if err := config.ReadInConfig(); err != nil {
		return nil, fmt.Errorf("Config file error: %s", err)
	}

	config.WatchConfig() // Watch the config

	return config, nil
}

func run() error {
	showVersion()

	config, err := getConfig()
	if err != nil {
		return err
	}
	panelConfig := &panel.Config{}
	if err := config.Unmarshal(panelConfig); err != nil {
		return fmt.Errorf("Parse config file %v failed: %s \n", cfgFile, err)
	}

	if panelConfig.LogConfig.Level == "debug" {
		log.SetReportCaller(true)
	}

	p := panel.New(panelConfig)
	lastTime := time.Now()
	config.OnConfigChange(func(e fsnotify.Event) {
		// Discarding event received within a short period of time after receiving an event.
		if time.Now().After(lastTime.Add(3 * time.Second)) {
			// Hot reload function
			fmt.Println("Config file changed:", e.Name)
			p.Close()
			// Delete old instance and trigger GC
			runtime.GC()
			if err := config.Unmarshal(panelConfig); err != nil {
				log.Panicf("Parse config file %v failed: %s \n", cfgFile, err)
			}

			if panelConfig.LogConfig.Level == "debug" {
				log.SetReportCaller(true)
			}

			p.Start()
			lastTime = time.Now()
		}
	})

	p.Start()
	defer p.Close()

	// Explicitly triggering GC to remove garbage from config loading.
	runtime.GC()
	// Running backend
	osSignals := make(chan os.Signal, 1)
	signal.Notify(osSignals, os.Interrupt, os.Kill, syscall.SIGTERM)
	<-osSignals

	return nil
}

func Execute() error {
	return rootCmd.Execute()
}

func showHelpWithoutConfig() {
	fmt.Println(strings.Repeat("=", 60))
	fmt.Println("           XrayR URL Logger 服务")
	fmt.Println(strings.Repeat("=", 60))
	fmt.Println()
	fmt.Println("❌ 配置文件不存在！")
	fmt.Println()
	fmt.Println("📋 可用的命令:")
	fmt.Println("  • xrayr status        - 显示服务状态和管理界面")
	fmt.Println("  • xrayr version       - 显示版本信息")
	fmt.Println("  • xrayr analyze       - 分析URL访问日志")
	fmt.Println("  • xrayr -c config.yml - 使用指定配置文件启动服务")
	fmt.Println()
	fmt.Println("💡 建议操作:")
	fmt.Println("  1. 创建配置文件 config.yml")
	fmt.Println("  2. 运行 'xrayr status' 查看服务状态")
	fmt.Println("  3. 使用 'systemctl start xrayr' 启动服务")
	fmt.Println()
	fmt.Println("📁 配置文件位置: /etc/XrayR/config.yml")
	fmt.Println("📊 URL日志位置: /var/log/xrayr/url_access.log")
	fmt.Println()
}
