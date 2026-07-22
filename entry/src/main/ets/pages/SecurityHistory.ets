import { SecurityRecord, getRecentRecords, getHistoryStats, clearHistory, HistoryStats } from '../service/SecurityHistory'
import { RiskLevel } from '../model/ChatModel'
import { shareText } from '../service/ShareService'
import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { APP_VERSION, APP_TEAM } from '../common/AppConstants'

@Entry
@Component
struct SecurityHistoryPage {
  @State records: SecurityRecord[] = []
  @State stats: HistoryStats = new HistoryStats()
  @State selectedTab: number = 0
  private trendSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private trendContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.trendSettings)

  aboutToAppear(): void {
    this.loadData()
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.None, duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
    PageTransitionExit({ type: RouteType.None, duration: 300, curve: Curve.EaseIn })
      .slide(SlideEffect.Left)
  }

  private loadData(): void {
    this.records = getRecentRecords(50)
    this.stats = getHistoryStats()
  }

  build() {
    Column() {
      this.TitleBar()
      this.SummaryCards()
      this.TrendChart()
      this.TabSelector()
      this.RecordList()
      Column() {
        Text(`谛听 v${APP_VERSION} · 端侧安全守护`)
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
        Text(APP_TEAM)
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 2 })
      }
      .width('100%')
      .padding({ top: 8, bottom: 12 })
      .alignItems(HorizontalAlign.Center)
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

      Text('安全记录')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Row() {
        Text('清除')
          .fontSize(13)
          .fontColor($r('app.color.accent_red'))
      }
      .width(40)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        this.getUIContext().getPromptAction().showDialog({
          title: '清除记录',
          message: '确定要清除所有安全检测记录吗？此操作不可撤销。',
          buttons: [
            // NOTE: Hardcoded hex colors required by dialog API — it only accepts string color values
            { text: '取消', color: '#007AFF' },
            { text: '清除', color: '#FF3B30' }
          ]
        }).then(async (data: promptAction.ShowDialogSuccessResponse) => {
          if (data.index === 1) {
            clearHistory()
            this.loadData()
          }
        }).catch(() => {})
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
  }

  @Builder
  SummaryCards() {
    Row() {
      this.SummaryCard('总记录', this.stats.total.toString(), $r('app.color.accent_purple'), $r('app.color.critical_badge_bg'))
      this.SummaryCard('今日', this.stats.todayCount.toString(), $r('app.color.accent_blue'), $r('app.color.accent_blue_light'))
      this.SummaryCard('安全', this.stats.safeCount.toString(), $r('app.color.risk_safe'), $r('app.color.safe_badge_bg'))
      this.SummaryCard('风险', (this.stats.suspiciousCount + this.stats.dangerousCount).toString(),
        this.stats.suspiciousCount + this.stats.dangerousCount > 0 ? $r('app.color.risk_dangerous') : $r('app.color.risk_safe'),
        this.stats.suspiciousCount + this.stats.dangerousCount > 0 ? $r('app.color.danger_badge_bg') : $r('app.color.safe_badge_bg'))
    }
    .width('100%')
     .padding({ left: 16, right: 16, top: 16, bottom: 4 })
    .justifyContent(FlexAlign.SpaceBetween)
  }

  @Builder
  SummaryCard(label: string, count: string, color: ResourceColor, bg: ResourceColor) {
    Column() {
      Text(count)
        .fontSize(22)
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
    .backgroundColor($r('app.color.card_bg'))
    .alignItems(HorizontalAlign.Center)
    .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
  }

  @Builder
  TrendChart() {
    Column() {
      Row() {
        Text('安全评分趋势')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Text('近7天')
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ bottom: 6 })
      Canvas(this.trendContext)
        .width('100%')
        .height(90)
        .onReady(() => {
          this.drawTrendChart()
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 8 })
    .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
  }

  private drawTrendChart(): void {
    const ctx = this.trendContext
    const allRecords = getRecentRecords(50)
    if (allRecords.length === 0) {
      ctx.fillStyle = '#C7C7CC'
      ctx.font = '12px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText('暂无数据', 160, 50)
      return
    }

    const dayBuckets: Map<string, number[]> = new Map()
    for (const r of allRecords) {
      const d = new Date(r.timestamp)
      const key = `${d.getMonth() + 1}/${d.getDate()}`
      let arr = dayBuckets.get(key)
      if (!arr) {
        arr = []
        dayBuckets.set(key, arr)
      }
      arr.push(this.riskToScore(r.riskLevel))
    }

    const keys: string[] = []
    dayBuckets.forEach((_v: number[], k: string) => {
      keys.push(k)
    })
    if (keys.length === 0) { return }

    const labels = keys.slice(-7)
    const values: number[] = []
    for (const label of labels) {
      const arr = dayBuckets.get(label) ?? [0]
      let sum = 0
      for (const v of arr) { sum += v }
      values.push(sum / arr.length)
    }

    const w = 320
    const h = 80
    const pad = 16
    const chartW = w - pad * 2
    const chartH = h - pad
    const maxVal = 100
    const step = labels.length > 1 ? chartW / (labels.length - 1) : chartW

    ctx.clearRect(0, 0, w, h)

    ctx.strokeStyle = '#E5E5EA'
    ctx.lineWidth = 0.5
    for (let i = 0; i <= 3; i++) {
      const y = pad + (chartH / 3) * i
      ctx.beginPath()
      ctx.moveTo(pad, y)
      ctx.lineTo(w - pad, y)
      ctx.stroke()
    }

    ctx.fillStyle = '#C7C7CC'
    ctx.font = '8px sans-serif'
    ctx.textAlign = 'right'
    ctx.fillText('100', pad - 3, pad + 4)
    ctx.fillText('50', pad - 3, pad + chartH / 2 + 3)
    ctx.fillText('0', pad - 3, pad + chartH + 3)

    const lastVal = values.length > 0 ? values[values.length - 1] : 100
    const lineColor = lastVal >= 80 ? '#34C759' : lastVal >= 60 ? '#FF9500' : '#FF3B30'
    const lineColorLight = lastVal >= 80 ? '#34C75930' : lastVal >= 60 ? '#FF950030' : '#FF3B3030'

    const gradient = ctx.createLinearGradient(0, pad, 0, pad + chartH)
    gradient.addColorStop(0.0, lineColorLight)
    gradient.addColorStop(1.0, '#00000005')

    ctx.strokeStyle = lineColor
    ctx.lineWidth = 2
    ctx.beginPath()
    for (let i = 0; i < values.length; i++) {
      const x = pad + step * i
      const y = pad + chartH - (values[i] / maxVal) * chartH
      if (i === 0) {
        ctx.moveTo(x, y)
      } else {
        ctx.lineTo(x, y)
      }
    }
    ctx.stroke()

    ctx.fillStyle = gradient
    ctx.beginPath()
    ctx.moveTo(pad, pad + chartH)
    for (let i = 0; i < values.length; i++) {
      const x = pad + step * i
      const y = pad + chartH - (values[i] / maxVal) * chartH
      ctx.lineTo(x, y)
    }
    ctx.lineTo(pad + step * (values.length - 1), pad + chartH)
    ctx.closePath()
    ctx.fill()

    for (let i = 0; i < values.length; i++) {
      const x = pad + step * i
      const y = pad + chartH - (values[i] / maxVal) * chartH
      const v = values[i]
      const dotColor = v >= 80 ? '#34C759' : v >= 60 ? '#FF9500' : '#FF3B30'
      ctx.fillStyle = '#FFFFFF'
      ctx.beginPath()
      ctx.arc(x, y, 5, 0, Math.PI * 2)
      ctx.fill()
      ctx.fillStyle = dotColor
      ctx.beginPath()
      ctx.arc(x, y, 3.5, 0, Math.PI * 2)
      ctx.fill()
    }

    ctx.fillStyle = '#8E8E93'
    ctx.font = '9px sans-serif'
    ctx.textAlign = 'center'
    for (let i = 0; i < labels.length; i++) {
      const x = pad + step * i
      ctx.fillText(labels[i], x, h - 2)
    }
  }

  private riskToScore(level: RiskLevel): number {
    if (level === RiskLevel.SAFE) { return 100 }
    if (level === RiskLevel.SUSPICIOUS) { return 60 }
    if (level === RiskLevel.DANGEROUS) { return 30 }
    if (level === RiskLevel.CRITICAL) { return 10 }
    return 80
  }

  @Builder
  TabSelector() {
    Row() {
      this.TabItem('全部', 0, $r('app.color.accent_blue'))
      this.TabItem('危险', 1, $r('app.color.risk_dangerous'))
      this.TabItem('可疑', 2, $r('app.color.risk_suspicious'))
      this.TabItem('安全', 3, $r('app.color.risk_safe'))
    }
    .width('100%')
     .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .justifyContent(FlexAlign.SpaceAround)
  }

  @Builder
  TabItem(label: string, index: number, color: ResourceColor) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.selectedTab === index ? color : $r('app.color.text_secondary'))
      Row()
        .width(16)
        .height(2)
        .borderRadius(1)
        .backgroundColor(this.selectedTab === index ? color : Color.Transparent)
          .margin({ top: 4 })
     }
     .padding({ left: 8, right: 8, top: 4, bottom: 4 })
     .onClick(() => {
      this.selectedTab = index
      if (index === 0) {
        this.records = getRecentRecords(50)
      } else if (index === 1) {
        this.records = getRecordsByLevel(RiskLevel.DANGEROUS, RiskLevel.CRITICAL)
      } else if (index === 2) {
        this.records = getRecordsByLevel(RiskLevel.SUSPICIOUS)
      } else {
        this.records = getRecordsByLevel(RiskLevel.SAFE)
      }
    })
  }

  @Builder
  RecordList() {
    if (this.records.length === 0) {
      Column() {
        Column() {
          Text('🛡️')
            .fontSize(48)
        }
        .width(88)
        .height(88)
        .borderRadius(22)
        .backgroundColor($r('app.color.accent_green_light'))
        .justifyContent(FlexAlign.Center)
        .margin({ bottom: 16 })

        Text(this.selectedTab === 0 ? '暂无检测记录' : '暂无此类记录')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(this.selectedTab === 0 ? '使用安全检测功能后，记录会显示在这里' : '试试切换其他标签查看')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
           .margin({ top: 8 })
       }
       .width('100%')
       .layoutWeight(1)
       .justifyContent(FlexAlign.Center)
       .alignItems(HorizontalAlign.Center)
     } else {
      List({ space: 6 }) {
        ForEach(this.records, (record: SecurityRecord) => {
          ListItem() {
            this.RecordCard(record)
          }
        }, (record: SecurityRecord) => record.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
       .padding({ left: 16, right: 16, top: 4 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  RecordCard(record: SecurityRecord) {
    Stack() {
      Row() {
         Row()
           .width(4)
           .height('100%')
           .borderRadius({ topLeft: 12, bottomLeft: 12 })
          .backgroundColor(this.getRiskColor(record.riskLevel))
        Row() {
          Column() {
            Row() {
              Column() {
                Row() {
                  Text(this.getRiskDot(record.riskLevel))
                    .fontSize(10)
                  Text(this.getToolLabel(record.toolName))
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                    .layoutWeight(1)
                    .margin({ left: 6 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                if (record.target.length > 0) {
                  Text(record.target)
                    .fontSize(11)
                    .fontColor($r('app.color.accent_blue'))
                     .margin({ top: 3, left: 8 })
                     .maxLines(1)
                     .textOverflow({ overflow: TextOverflow.Ellipsis })
                 }

                 Text(record.summary)
                   .fontSize(12)
                   .fontColor($r('app.color.text_secondary'))
                   .margin({ top: 3, left: 8 })
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Column() {
                Text(this.getRiskBadge(record.riskLevel))
                  .fontSize(10)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Medium)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(4)
                  .backgroundColor(this.getRiskColor(record.riskLevel))
                Text(this.formatTime(record.timestamp))
                  .fontSize(10)
                  .fontColor($r('app.color.text_tertiary'))
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.End)
              .margin({ left: 8 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }
          .layoutWeight(1)
         }
         .padding(16)
      }
      .width('100%')
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(12)
      .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
      .onClick(() => { this.shareRecord(record) })
      .accessibilityGroup(true)
      .accessibilityText(`${this.getToolLabel(record.toolName)}, ${this.getRiskBadge(record.riskLevel)}, ${record.summary}`)
      .accessibilityLevel('important')
    }
    .width('100%')
  }

  private getRiskDot(level: RiskLevel): string {
    if (level === RiskLevel.SUSPICIOUS) { return '🟡' }
    if (level === RiskLevel.DANGEROUS) { return '🔴' }
    if (level === RiskLevel.CRITICAL) { return '⛔' }
    return '🟢'
  }

  private getRiskBadge(level: RiskLevel): string {
    if (level === RiskLevel.SUSPICIOUS) { return '可疑' }
    if (level === RiskLevel.DANGEROUS) { return '危险' }
    if (level === RiskLevel.CRITICAL) { return '紧急' }
    return '安全'
  }

  private getRiskColor(level: RiskLevel): ResourceColor {
    if (level === RiskLevel.SUSPICIOUS) { return $r('app.color.risk_suspicious') }
    if (level === RiskLevel.DANGEROUS) { return $r('app.color.risk_dangerous') }
    if (level === RiskLevel.CRITICAL) { return $r('app.color.risk_critical') }
    return $r('app.color.risk_safe')
  }

  private getToolLabel(tool: string): string {
    if (tool === 'link_check') { return '🔗 链接检测' }
    if (tool === 'permission_scan') { return '🔐 权限分析' }
    if (tool === 'file_scan') { return '📁 文件扫描' }
    if (tool === 'network_monitor') { return '🌐 网络监控' }
    if (tool === 'privacy_health_check') { return '🛡️ 隐私体检' }
    if (tool === 'wifi_check') { return '📶 Wi-Fi检测' }
    if (tool === 'security_report') { return '📋 安全报告' }
    if (tool === 'device_security_check') { return '📱 设备安全' }
    if (tool === 'bluetooth') { return '📶 蓝牙守护' }
    if (tool === 'battery_usb') { return '🔋 电池USB守护' }
    if (tool === 'app_lifecycle') { return '📱 应用守护' }
    if (tool === 'sim') { return '📡 SIM卡守护' }
    return '🔍 安全检测'
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    const month = (date.getMonth() + 1).toString()
    const day = date.getDate().toString()
    const hour = date.getHours().toString().padStart(2, '0')
    const minute = date.getMinutes().toString().padStart(2, '0')
    return `${month}/${day} ${hour}:${minute}`
  }

  private shareRecord(record: SecurityRecord): void {
    try {
      const hostContext = this.getUIContext().getHostContext()
      if (hostContext) {
        const riskEmoji = record.riskLevel === RiskLevel.SAFE ? '🟢' :
          record.riskLevel === RiskLevel.SUSPICIOUS ? '🟡' :
          record.riskLevel === RiskLevel.DANGEROUS ? '🔴' : '⛔'
        const text = `🛡️ 谛听安全报告\n━━━━━━━━━━━━━━\n${riskEmoji} ${this.getToolLabel(record.toolName)} · ${this.getRiskBadge(record.riskLevel)}\n${record.target.length > 0 ? '🎯 目标: ' + record.target + '\n' : ''}📊 结果: ${record.summary}\n🕐 时间: ${this.formatTime(record.timestamp)}\n━━━━━━━━━━━━━━\n谛听 · 端侧安全守护 | v${APP_VERSION}`
        shareText(hostContext as common.UIAbilityContext, text)
      }
    } catch (_err) {
      // ignore
    }
  }
}

function getRecordsByLevel(...levels: RiskLevel[]): SecurityRecord[] {
  const all = getRecentRecords(200)
  const result: SecurityRecord[] = []
  for (const r of all) {
    for (const level of levels) {
      if (r.riskLevel === level) {
        result.push(r)
        break
      }
    }
  }
  return result
}
