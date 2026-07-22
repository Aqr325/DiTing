import { ChatMessage, MessageRole, RiskLevel } from '../model/ChatModel'
import { pasteboard } from '@kit.BasicServicesKit'
import { common } from '@kit.AbilityKit'
import { shareText } from '../service/ShareService'

class ContentSegment {
  type: string = 'text'
  text: string = ''
  key: number = 0

  constructor(type: string, text: string, key: number) {
    this.type = type
    this.text = text
    this.key = key
  }
}

@Component
export struct MessageBubble {
  @Prop message: ChatMessage = new ChatMessage(0, MessageRole.USER, '')
  @State expanded: boolean = false
  @State copied: boolean = false
  @State avatarScale: number = 1.0
  private pulseTimer: number = -1
  private copiedTimer: number = -1
  private segments: ContentSegment[] = []
  private segmentCounter: number = 0

  aboutToAppear(): void {
    if (this.message.role === MessageRole.AGENT) {
      this.segments = this.parseContent(this.message.content)
    }
    if (this.message.riskLevel === RiskLevel.DANGEROUS || this.message.riskLevel === RiskLevel.CRITICAL) {
      this.startPulse()
    }
  }

  private parseContent(content: string): ContentSegment[] {
    const result: ContentSegment[] = []
    const lines = content.split('\n')
    let i = 0
    const reDivider = new RegExp('^---+$')
    const reTitle = new RegExp('^## ')
    const reSubtitle = new RegExp('^### ')
    const reQuote = new RegExp('^> ')
    const reBullet = new RegExp('^• ')
    const reStructEnd = new RegExp('^(---+|## |### |> |• )$')
    while (i < lines.length) {
      const line = lines[i]
      if (reDivider.test(line)) {
        result.push(new ContentSegment('divider', '', this.segmentCounter++))
        i++
        continue
      }
      if (reTitle.test(line)) {
        result.push(new ContentSegment('title', line.substring(3), this.segmentCounter++))
        i++
        continue
      }
      if (reSubtitle.test(line)) {
        result.push(new ContentSegment('subtitle', line.substring(4), this.segmentCounter++))
        i++
        continue
      }
      if (reQuote.test(line)) {
        result.push(new ContentSegment('quote', line.substring(2), this.segmentCounter++))
        i++
        continue
      }
      if (reBullet.test(line)) {
        const bulletLines: string[] = [line.substring(2)]
        i++
        while (i < lines.length && reBullet.test(lines[i])) {
          bulletLines.push(lines[i].substring(2))
          i++
        }
        result.push(new ContentSegment('bullets', bulletLines.join('\n'), this.segmentCounter++))
        continue
      }
      if (line.length === 0) {
        result.push(new ContentSegment('blank', '', this.segmentCounter++))
        i++
        continue
      }
      const textLines: string[] = [line]
      i++
      while (i < lines.length && !reStructEnd.test(lines[i]) && lines[i].length > 0 &&
        !reDivider.test(lines[i]) && !reTitle.test(lines[i]) &&
        !reSubtitle.test(lines[i]) && !reQuote.test(lines[i]) && !reBullet.test(lines[i])) {
        textLines.push(lines[i])
        i++
      }
      result.push(new ContentSegment('text', textLines.join('\n'), this.segmentCounter++))
    }
    return result
  }

  private startPulse(): void {
    if (this.pulseTimer >= 0) { return }
    this.pulseTimer = setInterval(() => {
      this.avatarScale = this.avatarScale === 1.0 ? 1.08 : 1.0
    }, 800)
  }

  aboutToDisappear(): void {
    if (this.pulseTimer >= 0) {
      clearInterval(this.pulseTimer)
    }
    if (this.copiedTimer >= 0) {
      clearTimeout(this.copiedTimer)
    }
  }

  build() {
    Column() {
      if (this.message.role === MessageRole.AGENT) {
        this.AgentBubble()
      } else {
        this.UserBubble()
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .accessibilityGroup(true)
    .accessibilityText(this.getAccessibilityDesc())
    .accessibilityLevel('important')
  }

  @Builder
  AgentBubble() {
    Row() {
      Column() {
        Row() {
          Text('谛')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(32)
        .height(32)
        .borderRadius(8)
        .backgroundColor(this.getRiskColor())
        .justifyContent(FlexAlign.Center)
        .scale({ x: this.avatarScale, y: this.avatarScale })
        .animation({ duration: 400, curve: Curve.EaseInOut })
      }
      .margin({ right: 8 })

      Column() {
        Row() {
          Text('谛听')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
            .fontWeight(FontWeight.Medium)
          if (this.message.riskLevel !== RiskLevel.SAFE) {
            Text(this.getRiskLabel())
              .fontSize(10)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .borderRadius(4)
              .backgroundColor(this.getRiskColor())
              .margin({ left: 6 })
          }
        }
        .margin({ bottom: 4 })

        if (this.message.riskLevel === RiskLevel.DANGEROUS || this.message.riskLevel === RiskLevel.CRITICAL) {
          Row() {
            Text(this.message.riskLevel === RiskLevel.CRITICAL ? '⛔ 此检测结果为紧急级别，请立即处理' : '🔴 此检测结果为危险级别，建议谨慎处理')
              .fontSize(11)
              .fontColor(this.message.riskLevel === RiskLevel.CRITICAL ? $r('app.color.risk_critical') : $r('app.color.risk_dangerous'))
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius({ topLeft: 6, topRight: 6 })
          .backgroundColor(this.message.riskLevel === RiskLevel.CRITICAL ? $r('app.color.critical_badge_bg') : $r('app.color.danger_badge_bg'))
          .margin({ bottom: 4 })
        }

        Stack() {
          Column() {
            this.RichContent()
          }
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .constraintSize({ maxWidth: '85%' })
          .alignItems(HorizontalAlign.Start)
          .onClick(() => { this.expanded = !this.expanded })

          if (this.message.riskLevel !== RiskLevel.SAFE) {
            Row()
              .width(4)
              .height('100%')
              .backgroundColor(this.getRiskColor())
              .borderRadius({ topLeft: 2, bottomLeft: 2 })
              .align(Alignment.Start)
          }
        }
        .borderRadius(this.message.riskLevel === RiskLevel.DANGEROUS || this.message.riskLevel === RiskLevel.CRITICAL ? { topLeft: 0, topRight: 0, bottomLeft: 16, bottomRight: 16 } : { topLeft: 2, topRight: 16, bottomLeft: 16, bottomRight: 16 })
        .backgroundColor($r('app.color.card_bg'))
        .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
        .bindContextMenu(this.BubbleContextMenu(), ResponseType.LongPress)

        if (this.hasLongContent()) {
          Row() {
            Text(this.expanded ? '收起 ↑' : '展开全文 ↓')
              .fontSize(11)
              .fontColor($r('app.color.accent_blue'))
              .fontWeight(FontWeight.Medium)
          }
          .margin({ top: 4, left: 4 })
          .onClick(() => { this.expanded = !this.expanded })
        }

        this.ActionButtons()

        Text(this.formatTime(this.message.timestamp))
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 4, left: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  RichContent() {
    ForEach(this.segments, (seg: ContentSegment) => {
      if (seg.type === 'title') {
        Text(seg.text)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(24)
          .maxLines(this.expanded ? 999 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4, bottom: 4 })
      } else if (seg.type === 'subtitle') {
        Text(seg.text)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.accent_blue'))
          .lineHeight(20)
          .maxLines(this.expanded ? 999 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8, bottom: 4 })
      } else if (seg.type === 'divider') {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor($r('app.color.divider'))
          .margin({ top: 8, bottom: 8 })
      } else if (seg.type === 'quote') {
        Row() {
          Row()
            .width(3)
            .height('100%')
            .backgroundColor($r('app.color.accent_blue'))
            .borderRadius(2)
          Text(seg.text)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(20)
            .maxLines(this.expanded ? 999 : 4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .padding({ left: 8 })
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 6, bottom: 6, right: 8 })
        .borderRadius(6)
        .backgroundColor($r('app.color.accent_blue_light'))
        .margin({ top: 4, bottom: 4 })
        .alignItems(VerticalAlign.Center)
      } else if (seg.type === 'bullets') {
        Column() {
          ForEach(seg.text.split('\n'), (item: string, idx: number) => {
            Row() {
              Row()
                .width(4)
                .height(4)
                .borderRadius(2)
                .backgroundColor($r('app.color.accent_blue'))
                .margin({ right: 8, top: 8 })
              Text(item)
                .fontSize(13)
                .fontColor($r('app.color.text_primary'))
                .lineHeight(20)
                .maxLines(this.expanded ? 999 : 3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
          }, (item: string, idx: number) => `${seg.key}-${idx}`)
        }
        .margin({ top: 4, bottom: 4 })
      } else if (seg.type === 'blank') {
        Row()
          .height(6)
      } else {
        Text(seg.text)
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .lineHeight(22)
          .maxLines(this.expanded ? 999 : 6)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .copyOption(CopyOptions.LocalDevice)
      }
    }, (seg: ContentSegment) => seg.key.toString())
  }

  @Builder
  BubbleContextMenu() {
    Menu() {
      MenuItem({ content: '复制文本' })
        .onClick(() => { this.doCopy() })
      MenuItem({ content: '分享' })
        .onClick(() => { this.doShare() })
      if (this.hasLongContent()) {
        MenuItem({ content: this.expanded ? '收起' : '展开全文' })
          .onClick(() => { this.expanded = !this.expanded })
      }
    }
  }

  @Builder
  ActionButtons() {
    Row() {
      this.ActionChip(this.copied ? '已复制 ✓' : '复制', $r('app.color.text_secondary'), $r('app.color.chip_bg'), () => { this.doCopy() })
      this.ActionChip('分享', $r('app.color.accent_teal'), $r('app.color.accent_teal_light'), () => { this.doShare() })
      if (this.message.riskLevel === RiskLevel.DANGEROUS || this.message.riskLevel === RiskLevel.CRITICAL) {
        this.ActionChip('查看建议', $r('app.color.accent_blue'), $r('app.color.accent_blue_light'), () => { this.expanded = true })
      }
    }
    .margin({ top: 8, left: 4 })
  }

  private doCopy(): void {
    try {
      const sysPasteboard = pasteboard.getSystemPasteboard()
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.message.content)
      sysPasteboard.setData(pasteData)
      this.copied = true
      if (this.copiedTimer >= 0) {
        clearTimeout(this.copiedTimer)
      }
      this.copiedTimer = setTimeout(() => { this.copied = false }, 2000)
    } catch (_err) {
      // ignore
    }
  }

  private doShare(): void {
    try {
      const hostContext = this.getUIContext().getHostContext()
      if (hostContext) {
        shareText(hostContext as common.UIAbilityContext, this.message.content)
      }
    } catch (_err) {
      // ignore
    }
  }

  @Builder
  ActionChip(label: string, color: ResourceColor, bgColor: ResourceColor, action: () => void) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor(color)
        .fontWeight(FontWeight.Medium)
    }
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .borderRadius(10)
    .backgroundColor(bgColor)
    .margin({ right: 6 })
    .onClick(() => { action() })
  }

  @Builder
  UserBubble() {
    Row() {
      Column() {
        Column() {
          Text(this.message.content)
            .fontSize(14)
            .fontColor(Color.White)
            .lineHeight(22)
            .maxLines(999)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .copyOption(CopyOptions.LocalDevice)
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .borderRadius({ topLeft: 16, topRight: 2, bottomLeft: 16, bottomRight: 16 })
        .backgroundColor($r('app.color.bubble_user_bg'))
        .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
        .alignItems(HorizontalAlign.End)
        .constraintSize({ maxWidth: '80%' })
        .bindContextMenu(this.UserContextMenu(), ResponseType.LongPress)

        Text(this.formatTime(this.message.timestamp))
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.End)

      Column() {
        Row() {
          Text('我')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(32)
        .height(32)
        .borderRadius(8)
        .backgroundColor($r('app.color.accent_blue'))
        .justifyContent(FlexAlign.Center)
      }
      .margin({ left: 8 })
    }
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  UserContextMenu() {
    Menu() {
      MenuItem({ content: '复制文本' })
        .onClick(() => { this.doCopy() })
      MenuItem({ content: '分享' })
        .onClick(() => { this.doShare() })
    }
  }

  private getRiskColor(): ResourceColor {
    if (this.message.riskLevel === RiskLevel.SUSPICIOUS) { return $r('app.color.risk_suspicious') }
    if (this.message.riskLevel === RiskLevel.DANGEROUS) { return $r('app.color.risk_dangerous') }
    if (this.message.riskLevel === RiskLevel.CRITICAL) { return $r('app.color.risk_critical') }
    return $r('app.color.risk_safe')
  }

  private getRiskLabel(): string {
    if (this.message.riskLevel === RiskLevel.SUSPICIOUS) { return '⚠️ 可疑' }
    if (this.message.riskLevel === RiskLevel.DANGEROUS) { return '🔴 危险' }
    if (this.message.riskLevel === RiskLevel.CRITICAL) { return '⛔ 紧急' }
    return '🟢 安全'
  }

  private hasLongContent(): boolean {
    return this.message.content.length > 120
  }

  private formatTime(ts: number): string {
    const d = new Date(ts)
    const h = d.getHours().toString().padStart(2, '0')
    const m = d.getMinutes().toString().padStart(2, '0')
    return `${h}:${m}`
  }

  private getAccessibilityDesc(): string {
    const role = this.message.role === MessageRole.AGENT ? '谛听' : '我'
    const risk = this.message.riskLevel !== RiskLevel.SAFE ? `, ${this.getRiskLabel()}` : ''
    return `${role}${risk}: ${this.message.content}`
  }
}
