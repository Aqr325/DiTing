@Component
export struct QuickActionPanel {
  onAction: (action: string) => void = () => {}
  @State pressedIndex: number = -1

  private actions: ActionItem[] = []

  aboutToAppear(): void {
    this.actions = [
      new ActionItem('🔗', '链接检测', $r('app.color.accent_blue'), $r('app.color.accent_blue_light'), $r('app.color.accent_blue_border'), '帮我检测这个链接的安全性：https://example.com/login'),
      new ActionItem('🔐', '权限分析', $r('app.color.accent_purple'), $r('app.color.accent_purple_light'), $r('app.color.accent_purple_border'), '帮我分析微信的权限'),
      new ActionItem('📶', 'Wi-Fi', $r('app.color.accent_teal'), $r('app.color.accent_teal_light'), $r('app.color.accent_teal_border'), '帮我检查Wi-Fi安全'),
      new ActionItem('🌐', '网络', $r('app.color.accent_green'), $r('app.color.accent_green_light'), $r('app.color.accent_green_border'), '检查我当前的网络安全'),
      new ActionItem('🛡️', '全面体检', $r('app.color.accent_orange'), $r('app.color.accent_orange_light'), $r('app.color.accent_orange_border'), '给我做一个全面的隐私健康检查'),
      new ActionItem('📋', '安全报告', $r('app.color.accent_violet'), $r('app.color.accent_violet_light'), $r('app.color.accent_violet_border'), '生成安全报告'),
      new ActionItem('📱', '设备安全', $r('app.color.accent_pink'), $r('app.color.accent_pink_light'), $r('app.color.accent_pink_border'), '查看设备安全状态'),
      new ActionItem('📚', '安全知识', $r('app.color.accent_blue'), $r('app.color.accent_blue_light'), $r('app.color.accent_blue_border'), '教我一些安全知识')
    ]
  }

  build() {
    Column() {
      Row() {
        ForEach(this.actions.slice(0, 4), (item: ActionItem, index: number) => {
          this.PillAction(item, index)
        }, (item: ActionItem, index: number) => index.toString())
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 6 })

      Row() {
        ForEach(this.actions.slice(4, 8), (item: ActionItem, index: number) => {
          this.PillAction(item, index + 4)
        }, (item: ActionItem, index: number) => (index + 4).toString())
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .padding({ left: 8, right: 8 })
  }

  @Builder
  PillAction(item: ActionItem, index: number) {
    Row() {
      Text(item.icon)
        .fontSize(13)
        .margin({ right: 4 })
      Text(item.label)
        .fontSize(12)
        .fontColor(item.color)
        .fontWeight(FontWeight.Medium)
    }
     .padding({ left: 10, right: 12, top: 8, bottom: 8 })
    .borderRadius(16)
    .backgroundColor(item.bgColor)
    .border({ width: 0.5, color: item.borderColor, radius: 16 })
    .margin({ right: 6 })
    .scale({ x: this.pressedIndex === index ? 0.94 : 1.0, y: this.pressedIndex === index ? 0.94 : 1.0 })
    .animation({ duration: 100, curve: Curve.EaseOut })
    .onClick(() => { this.onAction(item.action) })
    .accessibilityText(`${item.icon} ${item.label}`)
    .accessibilityLevel('important')
    .gesture(
      LongPressGesture().onAction(() => {
        this.onAction(item.action)
      })
    )
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedIndex = index
      } else {
        this.pressedIndex = -1
      }
    })
  }
}

class ActionItem {
  icon: string = ''
  label: string = ''
  color: ResourceColor = ''
  bgColor: ResourceColor = ''
  borderColor: ResourceColor = ''
  action: string = ''

  constructor(icon: string, label: string, color: ResourceColor, bgColor: ResourceColor, borderColor: ResourceColor, action: string) {
    this.icon = icon
    this.label = label
    this.color = color
    this.bgColor = bgColor
    this.borderColor = borderColor
    this.action = action
  }
}
