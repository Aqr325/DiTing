import { RiskLevel } from '../model/ChatModel'
import { getHistoryStats, HistoryStats } from '../service/SecurityHistory'
import { isMonitoring } from '../service/ClipboardMonitor'
import { isNetworkWatching } from '../service/NetworkWatch'
import { isAppLifecycleMonitoring } from '../service/AppLifecycleMonitor'
import { isBatteryUsbMonitoring } from '../service/BatteryUsbMonitor'
import { isBluetoothMonitoring } from '../service/BluetoothMonitor'
import { isSimChangeMonitoring } from '../service/SimChangeMonitor'
import { checkWifiSecurity, WifiSecurityInfo } from '../service/WifiSecurity'
import { calcSecurityScore, SecurityScoreParams } from '../common/AppConstants'

@Component
export struct SecurityDashboard {
  @State stats: HistoryStats = new HistoryStats()
  @State clipboardOn: boolean = false
  @State netWatchOn: boolean = false
  @State appLifecycleOn: boolean = false
  @State batteryUsbOn: boolean = false
  @State bluetoothOn: boolean = false
  @State simChangeOn: boolean = false
  @State wifiSecure: boolean = true
  @State wifiName: string = ''
  @State wifiSecType: string = ''
  @State scoreAnim: number = 0
  @State scoreTrend: string = ''
  @State lastScore: number = 0
  @State lastScanTime: string = ''
  private refreshTimer: number = -1
  private targetScore: number = 100

  aboutToAppear(): void {
    this.refresh()
    this.refreshTimer = setInterval(() => {
      this.refresh()
    }, 30000)
  }

  aboutToDisappear(): void {
    if (this.refreshTimer >= 0) {
      clearInterval(this.refreshTimer)
    }
  }

  refresh(): void {
    this.stats = getHistoryStats()
    this.clipboardOn = isMonitoring()
    this.netWatchOn = isNetworkWatching()
    this.appLifecycleOn = isAppLifecycleMonitoring()
    this.batteryUsbOn = isBatteryUsbMonitoring()
    this.bluetoothOn = isBluetoothMonitoring()
    this.simChangeOn = isSimChangeMonitoring()
    this.refreshWifiInfo()
    const newScore = this.calcScore()
    if (this.targetScore > 0 && this.targetScore !== newScore) {
      if (newScore > this.targetScore) {
        this.scoreTrend = '↑'
      } else if (newScore < this.targetScore) {
        this.scoreTrend = '↓'
      }
    }
    this.lastScore = this.targetScore
    this.targetScore = newScore
    this.lastScanTime = this.formatCurrentTime()
    this.animateScore()
  }

  private animateScore(): void {
    const diff = this.targetScore - this.scoreAnim
    if (Math.abs(diff) < 2) {
      this.scoreAnim = this.targetScore
      return
    }
    const step = Math.ceil(Math.abs(diff) / 10)
    if (diff > 0) {
      this.scoreAnim = Math.min(this.targetScore, this.scoreAnim + step)
    } else {
      this.scoreAnim = Math.max(this.targetScore, this.scoreAnim - step)
    }
    setTimeout(() => { this.animateScore() }, 30)
  }

  private refreshWifiInfo(): void {
    try {
      const wifiInfo: WifiSecurityInfo = checkWifiSecurity()
      this.wifiName = wifiInfo.ssid
      this.wifiSecType = wifiInfo.securityType
      this.wifiSecure = wifiInfo.riskLevel === RiskLevel.SAFE
    } catch (_err) {
      this.wifiSecure = true
      this.wifiSecType = '未知'
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('安全仪表盘')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
           Text('实时监控设备安全状态')
             .fontSize(10)
             .fontColor($r('app.color.text_secondary'))
             .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Row() {
          Text('↻')
            .fontSize(13)
            .fontColor($r('app.color.accent_blue'))
        }
        .width(26)
        .height(26)
        .borderRadius(13)
        .backgroundColor($r('app.color.accent_blue_light'))
        .justifyContent(FlexAlign.Center)
         .margin({ right: 8 })
         .onClick(() => { this.refresh() })

         Row() {
           Row()
             .width(6)
             .height(6)
             .borderRadius(3)
             .backgroundColor($r('app.color.risk_safe'))
           Text('LIVE')
             .fontSize(10)
             .fontColor($r('app.color.risk_safe'))
             .fontWeight(FontWeight.Bold)
             .margin({ left: 4 })
        }
      }
       .width('100%')
       .margin({ bottom: 12 })

      Row() {
        this.ScoreRing()
        Column() {
          this.GuardItem('📋', '剪贴板', this.clipboardOn, '')
          this.GuardItem('🌐', '网络', this.netWatchOn, '')
          this.GuardItem('📶', 'Wi-Fi', this.wifiSecure,
            this.wifiSecure ? this.wifiSecType : this.wifiName)
          this.GuardItem('📱', '应用', this.appLifecycleOn, '')
          this.GuardItem('🔋', '电池', this.batteryUsbOn, '')
          this.GuardItem('📶', '蓝牙', this.bluetoothOn, '')
          this.GuardItem('📡', 'SIM', this.simChangeOn, '')
          this.GuardItem('🛡️', '守护', this.clipboardOn || this.netWatchOn, '')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

       Row() {
         this.MiniStat('总检测', this.stats.total.toString(), $r('app.color.accent_blue'))
         this.MiniStat('今日', this.stats.todayCount.toString(), $r('app.color.accent_purple'))
         this.MiniStat('安全', this.stats.safeCount.toString(), $r('app.color.risk_safe'))
         this.MiniStat('风险', (this.stats.suspiciousCount + this.stats.dangerousCount).toString(),
           this.stats.suspiciousCount + this.stats.dangerousCount > 0 ? $r('app.color.risk_suspicious') : $r('app.color.risk_safe'))
       }
       .width('100%')
       .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 12 })
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .borderRadius(8)
        .backgroundColor($r('app.color.page_bg'))

        if (this.lastScanTime.length > 0) {
          Row() {
            Text(`最近刷新: ${this.lastScanTime}`)
              .fontSize(10)
               .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
           .margin({ top: 8 })
         }

         if (this.stats.total > 0) {
           Row() {
             Text(this.getRecentSummary())
               .fontSize(10)
               .fontColor($r('app.color.text_secondary'))
           }
           .width('100%')
           .justifyContent(FlexAlign.Center)
           .margin({ top: 4 })
        }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
    .accessibilityGroup(true)
    .accessibilityText(`安全仪表盘，评分${this.scoreAnim}分${this.scoreTrend.length > 0 ? (this.scoreTrend === '↑' ? '上升' : '下降') : ''}，剪贴板${this.clipboardOn ? '已开启' : '未开启'}，网络${this.netWatchOn ? '已开启' : '未开启'}，Wi-Fi${this.wifiSecure ? '安全' : '不安全'}`)
    .accessibilityLevel('important')
  }

  @Builder
  ScoreRing() {
    Stack() {
      Progress({ value: this.scoreAnim, total: 100, type: ProgressType.Ring })
        .width(72)
        .height(72)
        .color(this.getScoreColor())
        .style({ strokeWidth: 6 })
      Column() {
        Row() {
          Text(this.scoreAnim.toString())
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor())
          if (this.scoreTrend.length > 0) {
            Text(this.scoreTrend)
              .fontSize(12)
              .fontColor(this.scoreTrend === '↑' ? $r('app.color.risk_safe') : $r('app.color.risk_dangerous'))
              .margin({ left: 2 })
          }
        }
        Row() {
          Text(this.getScoreEmoji())
            .fontSize(10)
            .margin({ right: 2 })
          Text('安全分')
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
        }
      }
    }
     .margin({ right: 12 })
    .shadow({ radius: 12, color: this.getScoreShadowColor(), offsetY: 0 })
  }

  @Builder
  GuardItem(icon: string, label: string, active: boolean, detail: string) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(13)
          .opacity(active ? 1.0 : 0.4)
        Text(label)
          .fontSize(12)
          .fontColor(active ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
           .margin({ left: 4 })
           .layoutWeight(1)
         if (detail.length > 0) {
           Text(detail)
             .fontSize(10)
            .fontColor(active ? $r('app.color.risk_safe') : $r('app.color.risk_dangerous'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 80 })
        }
        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(active ? $r('app.color.risk_safe') : $r('app.color.risk_dangerous'))
          .margin({ left: 4 })
      }
      .width('100%')
      Row() {
        Row()
          .width(active ? '100%' : '0%')
          .height(2)
          .borderRadius(1)
          .backgroundColor(active ? $r('app.color.risk_safe') : $r('app.color.risk_dangerous'))
          .animation({ duration: 500, curve: Curve.EaseOut })
      }
      .width('100%')
      .height(2)
      .borderRadius(1)
      .backgroundColor($r('app.color.divider'))
       .margin({ top: 4 })
     }
     .margin({ bottom: 4 })
  }

  @Builder
  MiniStat(label: string, value: string, color: ResourceColor) {
    Column() {
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
       Text(label)
         .fontSize(10)
         .fontColor($r('app.color.text_secondary'))
         .margin({ top: 2 })
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
  }

  private calcScore(): number {
    const anyMonitorOn = this.clipboardOn || this.netWatchOn || this.appLifecycleOn ||
      this.batteryUsbOn || this.bluetoothOn || this.simChangeOn
    const params = new SecurityScoreParams()
    params.totalChecks = this.stats.total
    params.dangerousCount = this.stats.dangerousCount
    params.suspiciousCount = this.stats.suspiciousCount
    params.wifiSecure = this.wifiSecure
    params.anyMonitorActive = anyMonitorOn
    return calcSecurityScore(params)
  }

  private getScoreColor(): ResourceColor {
    const score = this.scoreAnim
    if (score >= 80) { return $r('app.color.risk_safe') }
    if (score >= 60) { return $r('app.color.risk_suspicious') }
    return $r('app.color.risk_dangerous')
  }

  private getScoreEmoji(): string {
    const score = this.scoreAnim
    if (score >= 80) { return '🟢' }
    if (score >= 60) { return '🟡' }
    return '🔴'
  }

  private getRecentSummary(): string {
    if (this.stats.dangerousCount > 0 || this.stats.suspiciousCount > 0) {
      return `⚠️ 近期发现 ${this.stats.suspiciousCount + this.stats.dangerousCount} 项风险，建议查看安全记录`
    }
    return `✅ 近期 ${this.stats.total} 次检测全部安全，设备状态良好`
  }

  private getScoreShadowColor(): ResourceColor {
    const score = this.scoreAnim
    if (score >= 80) { return $r('app.color.accent_green_border') }
    if (score >= 60) { return $r('app.color.accent_orange_border') }
    return $r('app.color.accent_red_border')
  }

  private formatCurrentTime(): string {
    const d = new Date()
    const h = d.getHours().toString().padStart(2, '0')
    const m = d.getMinutes().toString().padStart(2, '0')
    const s = d.getSeconds().toString().padStart(2, '0')
    return `${h}:${m}:${s}`
  }
}
