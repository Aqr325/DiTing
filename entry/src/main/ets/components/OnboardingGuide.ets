@Component
export struct OnboardingGuide {
  @State currentStep: number = 0
  @Prop showOnboarding: boolean = false
  @State ctaScale: number = 1.0
  onClose: () => void = () => {}
  onEnableMonitor: () => void = () => {}

  private steps: OnboardingStep[] = []

  aboutToAppear(): void {
    this.steps = [
      new OnboardingStep('🛡️', '欢迎来到谛听',
        '你的 24/7 端侧安全守护伙伴\n所有分析在设备端完成，绝不上传你的数据',
        ['端侧AI推理，无需联网', '13项安全能力 · 6大守护', '小艺智能体联动']),
      new OnboardingStep('🔗', '链接安全检测',
        '直接发链接或复制链接，立即分析是否为钓鱼或恶意网站',
        ['HTTP/钓鱼关键词/IP域名检测', '同形字攻击·Punycode识别', '剪贴板自动检测']),
      new OnboardingStep('🔐', '权限与隐私守护',
        '分析应用权限合理性，全面评估隐私健康状态',
        ['15+知名App权限分析', '5维度隐私健康评分', '可操作的建议']),
      new OnboardingStep('🌐📶', '网络与Wi-Fi守护',
        '实时监控网络安全，检测不安全Wi-Fi，风险自动告警',
        ['Portal/未验证网络告警', 'WPA3/BSSID热点识别', '连接变化实时推送']),
      new OnboardingStep('🚀', '开启主动守护',
        '开启守护后，谛听在后台自动检测风险并推送告警',
        ['剪贴板链接自动检测', '网络状态实时监控', '每日安全小贴士'])
    ]
    this.startPulse()
  }

  private pulseTimer: number = -1

  private startPulse(): void {
    this.pulseTimer = setInterval(() => {
      if (this.currentStep === this.steps.length - 1) {
        this.ctaScale = 1.04
        setTimeout(() => { this.ctaScale = 1.0 }, 400)
      }
    }, 2000)
  }

  aboutToDisappear(): void {
    if (this.pulseTimer !== -1) {
      clearInterval(this.pulseTimer)
    }
  }

  build() {
    Column() {
      Row() {
        Text('跳过')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .onClick(() => { this.onClose() })
      .width('100%')
      .justifyContent(FlexAlign.End)
       .padding({ right: 24, top: 16 })

      Column() {
        Column() {
          Text(this.steps[this.currentStep].icon)
            .fontSize(60)
        }
        .width(100)
        .height(100)
        .borderRadius(24)
        .backgroundColor($r('app.color.accent_blue_light'))
        .justifyContent(FlexAlign.Center)
        .border({ width: 2, color: $r('app.color.accent_blue_border'), radius: 24 })
        .margin({ bottom: 24 })

        Text(this.steps[this.currentStep].title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .margin({ bottom: 10 })

        Text(this.steps[this.currentStep].desc)
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(24)
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
          .margin({ bottom: 20 })

        Column() {
          ForEach(this.steps[this.currentStep].highlights, (item: string) => {
            Row() {
              Row()
                .width(6)
                .height(6)
                .borderRadius(3)
                .backgroundColor($r('app.color.accent_blue'))
                .margin({ right: 8 })
              Text(item)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
            }
            .margin({ top: 8, bottom: 8 })
          }, (item: string, index: number) => index.toString())
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 40, right: 40 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .width('100%')

      Row() {
        ForEach(this.steps, (_step: OnboardingStep, index: number) => {
          Row()
            .width(index === this.currentStep ? 24 : 8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(index === this.currentStep ? $r('app.color.accent_blue') : $r('app.color.text_tertiary'))
            .margin({ left: 4, right: 4 })
            .animation({ duration: 200 })
        }, (_step: OnboardingStep, index: number) => index.toString())
      }
      .margin({ bottom: 28 })

      Row() {
        if (this.currentStep > 0) {
          Row() {
            Text('← 上一步')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .fontWeight(FontWeight.Medium)
          }
           .padding({ left: 16, right: 16, top: 12, bottom: 12 })
           .borderRadius(25)
          .backgroundColor($r('app.color.page_bg'))
          .margin({ right: 12 })
          .onClick(() => {
            if (this.currentStep > 0) { this.currentStep-- }
          })
        }

        Row() {
          if (this.currentStep < this.steps.length - 1) {
            Text('下一步 →')
              .fontSize(16)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Medium)
          } else {
            Text('🛡️ 开启守护')
              .fontSize(16)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
        }
        .layoutWeight(1)
        .height(50)
        .borderRadius(25)
        .backgroundColor(this.currentStep < this.steps.length - 1 ? $r('app.color.accent_blue') : $r('app.color.accent_green'))
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: this.currentStep === this.steps.length - 1 ? 16 : 8, color: this.currentStep < this.steps.length - 1 ? $r('app.color.accent_blue_border') : $r('app.color.accent_green_border'), offsetY: 2 })
        .scale({ x: this.currentStep === this.steps.length - 1 ? this.ctaScale : 1.0, y: this.currentStep === this.steps.length - 1 ? this.ctaScale : 1.0 })
        .animation({ duration: 600, curve: Curve.EaseInOut })
        .onClick(() => {
          if (this.currentStep < this.steps.length - 1) {
            this.currentStep++
          } else {
            this.ctaScale = 0.95
            setTimeout(() => { this.ctaScale = 1.0 }, 150)
            this.onEnableMonitor()
            this.onClose()
          }
        })
      }
      .width('100%')
       .padding({ left: 16, right: 16, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: 68 })
    .backgroundColor($r('app.color.onboarding_bg'))
  }
}

class OnboardingStep {
  icon: string = ''
  title: string = ''
  desc: string = ''
  highlights: string[] = []

  constructor(icon: string, title: string, desc: string, highlights: string[]) {
    this.icon = icon
    this.title = title
    this.desc = desc
    this.highlights = highlights
  }
}
