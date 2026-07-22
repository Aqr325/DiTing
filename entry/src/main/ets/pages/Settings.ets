import { startClipboardMonitor, stopClipboardMonitor, isMonitoring } from '../service/ClipboardMonitor'
import { startNetworkWatch, stopNetworkWatch, isNetworkWatching } from '../service/NetworkWatch'
import { startAppLifecycleMonitor, stopAppLifecycleMonitor, isAppLifecycleMonitoring } from '../service/AppLifecycleMonitor'
import { startBatteryUsbMonitor, stopBatteryUsbMonitor, isBatteryUsbMonitoring } from '../service/BatteryUsbMonitor'
import { startBluetoothMonitor, stopBluetoothMonitor, isBluetoothMonitoring } from '../service/BluetoothMonitor'
import { startSimChangeMonitor, stopSimChangeMonitor, isSimChangeMonitoring } from '../service/SimChangeMonitor'
import { getHistoryStats, HistoryStats } from '../service/SecurityHistory'
import { triggerLightHaptic } from '../service/HapticService'
import { APP_VERSION, APP_SLOGAN, APP_TEAM } from '../common/AppConstants'
import { initMonitorOrchestrator, isMonitorOrchestratorInitialized, destroyMonitorOrchestrator } from '../service/MonitorOrchestrator'
import { ChatMessage, RiskLevel } from '../model/ChatModel'

@Entry
@Component
struct SettingsPage {
  @State clipboardMonitorOn: boolean = false
  @State networkWatchOn: boolean = false
  @State appLifecycleOn: boolean = false
  @State batteryUsbOn: boolean = false
  @State bluetoothOn: boolean = false
  @State simChangeOn: boolean = false
  @State stats: HistoryStats = new HistoryStats()
  @State anyMonitorOn: boolean = false

  aboutToAppear(): void {
    this.clipboardMonitorOn = isMonitoring()
    this.networkWatchOn = isNetworkWatching()
    this.appLifecycleOn = isAppLifecycleMonitoring()
    this.batteryUsbOn = isBatteryUsbMonitoring()
    this.bluetoothOn = isBluetoothMonitoring()
    this.simChangeOn = isSimChangeMonitoring()
    this.anyMonitorOn = this.clipboardMonitorOn || this.networkWatchOn ||
      this.appLifecycleOn || this.batteryUsbOn || this.bluetoothOn || this.simChangeOn
    this.stats = getHistoryStats()
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.None, duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
    PageTransitionExit({ type: RouteType.None, duration: 300, curve: Curve.EaseIn })
      .slide(SlideEffect.Left)
  }

  build() {
    Column() {
      this.TitleBar()
      this.MainContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  @Builder
  TitleBar() {
    Row() {
      Row() {
        Text('←')
          .fontSize(20)
          .fontColor($r('app.color.accent_blue'))
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.getUIContext().getRouter().back()
      })

      Text('设置')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Row().width(40)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
  }

  @Builder
  MainContent() {
    Scroll() {
      Column() {
        this.SectionHeader('实时守护')
        Column() {
          this.ToggleRow('📋', '剪贴板守护', '自动检测复制的链接安全性',
            this.clipboardMonitorOn, $r('app.color.risk_safe'), (isOn: boolean) => {
              if (isOn) {
                if (!this.anyMonitorOn) {
                  if (!isMonitorOrchestratorInitialized()) { initMonitorOrchestrator((_message: string, _riskLevel: RiskLevel, _toolName: string) => {}) }
                }
                startClipboardMonitor((_url: string, _msg: ChatMessage) => {})
                this.clipboardMonitorOn = true
                this.anyMonitorOn = true
              } else {
                stopClipboardMonitor()
                this.clipboardMonitorOn = false
                this.anyMonitorOn = this.networkWatchOn || this.appLifecycleOn ||
                  this.batteryUsbOn || this.bluetoothOn || this.simChangeOn
                if (!this.anyMonitorOn) {
                  destroyMonitorOrchestrator()
                }
              }
            })
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.ToggleRow('🌐', '网络守护', '实时监控网络连接和WiFi安全',
            this.networkWatchOn, $r('app.color.accent_teal'), (isOn: boolean) => {
              if (isOn) {
                if (!this.anyMonitorOn) {
                  if (!isMonitorOrchestratorInitialized()) { initMonitorOrchestrator((_message: string, _riskLevel: RiskLevel, _toolName: string) => {}) }
                }
                startNetworkWatch((_message: string) => {})
                this.networkWatchOn = true
                this.anyMonitorOn = true
              } else {
                stopNetworkWatch()
                this.networkWatchOn = false
                this.anyMonitorOn = this.clipboardMonitorOn || this.appLifecycleOn ||
                  this.batteryUsbOn || this.bluetoothOn || this.simChangeOn
                if (!this.anyMonitorOn) {
                  destroyMonitorOrchestrator()
                }
              }
            })
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.ToggleRow('📱', '应用守护', '监控应用安装/卸载/更新',
            this.appLifecycleOn, $r('app.color.accent_blue'), (isOn: boolean) => {
              if (isOn) {
                if (!this.anyMonitorOn) {
                  if (!isMonitorOrchestratorInitialized()) { initMonitorOrchestrator((_message: string, _riskLevel: RiskLevel, _toolName: string) => {}) }
                }
                startAppLifecycleMonitor()
                this.appLifecycleOn = true
                this.anyMonitorOn = true
              } else {
                stopAppLifecycleMonitor()
                this.appLifecycleOn = false
                this.anyMonitorOn = this.clipboardMonitorOn || this.networkWatchOn ||
                  this.batteryUsbOn || this.bluetoothOn || this.simChangeOn
                if (!this.anyMonitorOn) {
                  destroyMonitorOrchestrator()
                }
              }
            })
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.ToggleRow('🔋', '电池USB守护', '异常耗电检测 · USB安全提醒 · 温度监控',
            this.batteryUsbOn, $r('app.color.accent_orange'), (isOn: boolean) => {
              if (isOn) {
                if (!this.anyMonitorOn) {
                  if (!isMonitorOrchestratorInitialized()) { initMonitorOrchestrator((_message: string, _riskLevel: RiskLevel, _toolName: string) => {}) }
                }
                startBatteryUsbMonitor()
                this.batteryUsbOn = true
                this.anyMonitorOn = true
              } else {
                stopBatteryUsbMonitor()
                this.batteryUsbOn = false
                this.anyMonitorOn = this.clipboardMonitorOn || this.networkWatchOn ||
                  this.appLifecycleOn || this.bluetoothOn || this.simChangeOn
                if (!this.anyMonitorOn) {
                  destroyMonitorOrchestrator()
                }
              }
            })
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.ToggleRow('📶', '蓝牙守护', '配对检测 · 连接监控 · 30分钟未用提醒',
            this.bluetoothOn, $r('app.color.accent_purple'), (isOn: boolean) => {
              if (isOn) {
                if (!this.anyMonitorOn) {
                  if (!isMonitorOrchestratorInitialized()) { initMonitorOrchestrator((_message: string, _riskLevel: RiskLevel, _toolName: string) => {}) }
                }
                startBluetoothMonitor()
                this.bluetoothOn = true
                this.anyMonitorOn = true
              } else {
                stopBluetoothMonitor()
                this.bluetoothOn = false
                this.anyMonitorOn = this.clipboardMonitorOn || this.networkWatchOn ||
                  this.appLifecycleOn || this.batteryUsbOn || this.simChangeOn
                if (!this.anyMonitorOn) {
                  destroyMonitorOrchestrator()
                }
              }
            })
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.ToggleRow('📡', 'SIM卡守护', 'SIM卡变更检测 · 换卡攻击识别',
            this.simChangeOn, $r('app.color.accent_green'), (isOn: boolean) => {
              if (isOn) {
                if (!this.anyMonitorOn) {
                  if (!isMonitorOrchestratorInitialized()) { initMonitorOrchestrator((_message: string, _riskLevel: RiskLevel, _toolName: string) => {}) }
                }
                startSimChangeMonitor()
                this.simChangeOn = true
                this.anyMonitorOn = true
              } else {
                stopSimChangeMonitor()
                this.simChangeOn = false
                this.anyMonitorOn = this.clipboardMonitorOn || this.networkWatchOn ||
                  this.appLifecycleOn || this.batteryUsbOn || this.bluetoothOn
                if (!this.anyMonitorOn) {
                  destroyMonitorOrchestrator()
                }
              }
            })
        }
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(12)
        .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })

        this.SectionHeader('需系统签名（暂未开放）')
        Column() {
          this.FeatureRow('💾', '文件系统监控', '需系统签名 · 监控敏感目录读写')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('📸', '截图检测', '需系统签名 · 检测后台截屏行为')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('⚙️', '进程监控', '需系统签名 · 检测恶意后台进程')
        }
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(12)
        .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
        .opacity(0.6)

        this.SectionHeader('安全统计')
        Row() {
          this.StatCard(this.stats.total.toString(), '总检测', $r('app.color.accent_blue'), $r('app.color.accent_blue_light'))
          this.StatCard(this.stats.todayCount.toString(), '今日', $r('app.color.accent_purple'), $r('app.color.critical_badge_bg'))
          this.StatCard((this.stats.suspiciousCount + this.stats.dangerousCount).toString(), '风险', $r('app.color.accent_orange'), $r('app.color.warn_badge_bg'))
          this.StatCard(this.getScoreText(), '评分', $r('app.color.risk_safe'), $r('app.color.safe_badge_bg'))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)

        this.SectionHeader('13大安全能力')
        Column() {
          this.FeatureRow('🔗', '链接安全检测', '钓鱼关键词 · 同形字攻击 · Punycode · 高风险TLD · 短链接')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('🔐', '应用权限分析', '15+知名App · 分类判断 · 过度索权 · 最小权限建议')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('📁', '文件安全扫描', '勒索软件 · 双扩展名 · Office宏 · 18种危险扩展名')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('🌐', '网络安全监控', 'Portal检测 · 网络切换提醒 · 实时守护 · Wi-Fi联动')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('📶', 'Wi-Fi安全检测', 'WPA3/SAE · BSSID热点识别 · 4级信号质量 · 隐藏SSID')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('🛡️', '隐私健康评分', '5维度评分 · 逐项分析 · 可操作建议 · 趋势追踪')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('📋', '安全报告生成', '综合评分 · 分项分析 · 编号建议 · 可分享文本')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('📋', '剪贴板守护', '1.5s防抖 · 5s去重 · 多URL检测 · 自动分析')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('📱', '应用守护', '安装/卸载/更新监控 · 高风险应用检测 · 安全应用保护')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('🔋', '电池USB守护', '异常耗电检测 · USB连接提醒 · 温度监控 · 充电桩警告')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('📶', '蓝牙守护', '配对检测 · 连接状态轮询 · 长时未用提醒')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('📡', 'SIM卡守护', 'SIM变更检测 · 换卡攻击识别(ABSENT→READY 60秒)')
          Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 48 })
          this.FeatureRow('🤖', '小艺智能体', 'A2A协议 · 8项技能 · 深度链接 · 触感提醒')
        }
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(12)
        .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })

        this.SectionHeader('关于')
        Column() {
          Row() {
            Column() {
              Text('🛡️')
                .fontSize(40)
            }
            .width(72)
            .height(72)
            .borderRadius(18)
            .backgroundColor($r('app.color.accent_green_light'))
            .justifyContent(FlexAlign.Center)
             .margin({ top: 8, bottom: 8 })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Text('谛听 · 安全守护')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ bottom: 4 })

          Row() {
            Text(`v${APP_VERSION}`)
              .fontSize(11)
              .fontColor($r('app.color.accent_blue'))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor($r('app.color.accent_blue_light'))
            Text('API 24')
              .fontSize(11)
              .fontColor($r('app.color.accent_purple'))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor($r('app.color.critical_badge_bg'))
              .margin({ left: 6 })
            Text('HarmonyOS 6')
              .fontSize(11)
              .fontColor($r('app.color.accent_green'))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(6)
              .backgroundColor($r('app.color.accent_green_light'))
              .margin({ left: 6 })
          }
          .margin({ bottom: 8 })

           Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 16, bottom: 4 })
           this.StatRow('引擎', '端侧AI · AgentExtensionAbility')
           Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 16 })
           this.StatRow('协议', 'A2A · Agent-to-Agent')
           Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 16 })
           this.StatRow('赛事', '2026 C4-AI HarmonyOS Agent创新方向')
           Row().width('100%').height(0.5).backgroundColor($r('app.color.divider')).margin({ left: 16 })

          Row() {
            Column() {
              Text(APP_SLOGAN)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
              Text('所有分析在设备端完成，绝不上传你的数据')
                .fontSize(11)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 4 })
              Row() {
                 Text('13项安全能力 · 6大守护 · A2A协议 · 暗色模式 · 无障碍')
                   .fontSize(10)
                  .fontColor($r('app.color.text_tertiary'))
              }
              .margin({ top: 6 })
              Text(APP_TEAM)
                .fontSize(10)
                .fontColor($r('app.color.text_tertiary'))
                .margin({ top: 8 })
            }
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
           .padding({ top: 16, bottom: 16 })
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(12)
        .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
      }
       .padding({ left: 16, right: 16, top: 16, bottom: 32 })
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder
  SectionHeader(title: string) {
    Row() {
      Text(title)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
     .margin({ top: 20, bottom: 8 })
  }

  @Builder
  ToggleRow(icon: string, title: string, desc: string, isOn: boolean, color: ResourceColor, onChange: (isOn: boolean) => void) {
    Row() {
      Text(icon)
        .fontSize(20)
        .margin({ right: 8 })
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .fontWeight(FontWeight.Medium)
        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .width(48)
        .height(28)
        .selectedColor(color)
        .onChange((val: boolean) => { triggerLightHaptic(); onChange(val) })
    }
    .width('100%')
    .padding(16)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  StatCard(value: string, label: string, color: ResourceColor, bg: ResourceColor) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(10)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 2 })
    }
     .width('23%')
     .padding({ top: 8, bottom: 8 })
    .borderRadius(10)
    .backgroundColor(bg)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  StatRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Text(value)
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding({ top: 12, bottom: 12, left: 16, right: 16 })
  }

  @Builder
  FeatureRow(icon: string, title: string, desc: string) {
    Row() {
      Row() {
        Text(icon)
          .fontSize(14)
      }
      .width(30)
      .height(30)
      .borderRadius(8)
      .backgroundColor($r('app.color.page_bg'))
      .justifyContent(FlexAlign.Center)
       .margin({ right: 8 })
       Column() {
         Text(title)
           .fontSize(14)
           .fontColor($r('app.color.text_primary'))
           .fontWeight(FontWeight.Medium)
         Text(desc)
           .fontSize(11)
           .fontColor($r('app.color.text_secondary'))
           .margin({ top: 2 })
       }
       .alignItems(HorizontalAlign.Start)
       .layoutWeight(1)
     }
     .width('100%')
     .padding({ top: 10, bottom: 10, left: 16, right: 16 })
     .alignItems(VerticalAlign.Center)
  }

  private getScoreText(): string {
    const risk = this.stats.suspiciousCount + this.stats.dangerousCount * 2
    const score = Math.max(0, 100 - risk * 10)
    return score.toString()
  }
}
