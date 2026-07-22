import { ChatMessage, MessageRole, RiskLevel } from '../model/ChatModel'
import { processUserInput, getTimeGreeting } from '../service/AgentService'
import { MessageBubble } from '../components/MessageBubble'
import { QuickActionPanel } from '../components/QuickActionPanel'
import { SecurityDashboard } from '../components/SecurityDashboard'
import { OnboardingGuide } from '../components/OnboardingGuide'
import { sendSecurityAlert, formatAlertTitle } from '../service/NotificationService'
import { startClipboardMonitor, stopClipboardMonitor, isMonitoring } from '../service/ClipboardMonitor'
import { startNetworkWatch, stopNetworkWatch, isNetworkWatching } from '../service/NetworkWatch'
import { initHistoryStore, addSecurityRecord, getHistoryStats } from '../service/SecurityHistory'
import { initDailyTip, checkAndSendDailyTip, shouldShowDailyTip, getCurrentTip, markDailyTipShown } from '../service/DailyTip'
import { triggerHaptic, triggerLightHaptic } from '../service/HapticService'
import { APP_SLOGAN, calcSecurityScore, SecurityScoreParams } from '../common/AppConstants'
import { initMonitorOrchestrator, isMonitorOrchestratorInitialized, getActiveMonitorCount, destroyMonitorOrchestrator } from '../service/MonitorOrchestrator'
import { startAppLifecycleMonitor, stopAppLifecycleMonitor, isAppLifecycleMonitoring } from '../service/AppLifecycleMonitor'
import { startBatteryUsbMonitor, stopBatteryUsbMonitor, isBatteryUsbMonitoring } from '../service/BatteryUsbMonitor'
import { startBluetoothMonitor, stopBluetoothMonitor, isBluetoothMonitoring } from '../service/BluetoothMonitor'
import { startSimChangeMonitor, stopSimChangeMonitor, isSimChangeMonitoring } from '../service/SimChangeMonitor'
import { KeyboardAvoidMode, router } from '@kit.ArkUI'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { notificationManager } from '@kit.NotificationKit'
import { pasteboard } from '@kit.BasicServicesKit'

const READ_PASTEBOARD_PERMISSION: Permissions = 'ohos.permission.READ_PASTEBOARD'
const APPROXIMATELY_LOCATION_PERMISSION: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION'
const ACCESS_BLUETOOTH_PERMISSION: Permissions = 'ohos.permission.ACCESS_BLUETOOTH'

@Entry
@Component
struct Index {
  @State chatList: ChatMessage[] = []
  @State inputText: string = ''
  @State isSending: boolean = false
  @State showWelcome: boolean = true
  @State dailyTip: string = ''
  @State monitorActive: boolean = false
  @State netWatchActive: boolean = false
  @State appLifecycleActive: boolean = false
  @State batteryUsbActive: boolean = false
  @State bluetoothActive: boolean = false
  @State simChangeActive: boolean = false
  @State showDashboard: boolean = true
  @State showOnboarding: boolean = false
  @State showScrollFab: boolean = false
  @State shieldY: number = 0
  private listScroller: Scroller = new Scroller()
  private nextId: number = 1
  private floatTimer: number = -1

  pageTransition() {
    PageTransitionEnter({ type: RouteType.None, duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ type: RouteType.None, duration: 300, curve: Curve.EaseIn })
      .slide(SlideEffect.Right)
  }

  aboutToAppear(): void {
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)
    const greeting = getTimeGreeting()
    const welcomeMsg = new ChatMessage(this.nextId++, MessageRole.AGENT,
      `${greeting}我是谛听，你的 24/7 端侧安全守护伙伴。\n\n` +
      '我可以帮你：\n' +
      '🔗  检测链接安全性 — 直接发链接给我\n' +
      '🔐  分析应用权限 — "检查XX应用权限"\n' +
      '📁  扫描文件安全 — "扫描文件 xxx"\n' +
      '🌐  监控网络安全 — "检查网络"\n' +
      '📶  Wi-Fi安全检测 — "检查Wi-Fi安全"\n' +
      '🛡️  隐私健康评分 — "全面检查"\n' +
      '📋  生成安全报告 — "生成安全报告"\n' +
      '📱  设备安全状态 — "设备安全"')
    this.chatList = [welcomeMsg]
    this.checkFirstLaunch()
    this.initServices()
    this.checkIncomingUrl()
    this.floatTimer = setInterval(() => {
      this.shieldY = this.shieldY === 0 ? -4 : 0
    }, 2000)
  }

  aboutToDisappear(): void {
    destroyMonitorOrchestrator()
    stopClipboardMonitor()
    stopNetworkWatch()
    stopAppLifecycleMonitor()
    stopBatteryUsbMonitor()
    stopBluetoothMonitor()
    stopSimChangeMonitor()
    if (this.floatTimer >= 0) {
      clearInterval(this.floatTimer)
    }
  }

  onPageShow(): void {
    if (!isMonitorOrchestratorInitialized() && (isMonitoring() || isNetworkWatching() ||
      isAppLifecycleMonitoring() || isBatteryUsbMonitoring() || isBluetoothMonitoring() || isSimChangeMonitoring())) {
      initMonitorOrchestrator((message: string, riskLevel: RiskLevel, _toolName: string) => {
        const alertMsg = new ChatMessage(this.nextId++, MessageRole.SYSTEM, message)
        alertMsg.riskLevel = riskLevel
        this.chatList = this.chatList.concat([alertMsg])
        this.showWelcome = false
        this.showDashboard = false
        if (riskLevel === RiskLevel.DANGEROUS || riskLevel === RiskLevel.CRITICAL) {
          sendSecurityAlert(formatAlertTitle(riskLevel), message.substring(0, 100), riskLevel)
          triggerHaptic(riskLevel)
        } else if (riskLevel === RiskLevel.SUSPICIOUS) {
          triggerHaptic(RiskLevel.SUSPICIOUS)
        }
        setTimeout(() => { this.listScroller.scrollEdge(Edge.Bottom) }, 100)
      })
    }
    this.syncMonitorStates()
  }

  private syncMonitorStates(): void {
    this.monitorActive = isMonitoring()
    this.netWatchActive = isNetworkWatching()
    this.appLifecycleActive = isAppLifecycleMonitoring()
    this.batteryUsbActive = isBatteryUsbMonitoring()
    this.bluetoothActive = isBluetoothMonitoring()
    this.simChangeActive = isSimChangeMonitoring()
  }

  private async initServices(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext()
      if (hostContext) {
        const context = hostContext as common.UIAbilityContext
        await initHistoryStore(context)
        await initDailyTip(context)
        const showTip = await shouldShowDailyTip()
        if (showTip) {
          await checkAndSendDailyTip()
          const tipContent = getCurrentTip()
          const tipMsg = new ChatMessage(this.nextId++, MessageRole.AGENT,
            '💡 今日安全小贴士\n\n' + tipContent)
          tipMsg.riskLevel = RiskLevel.SAFE
          this.chatList = this.chatList.concat([tipMsg])
          this.dailyTip = tipContent
          await markDailyTipShown()
        }
      }
    } catch (err) {
      const e = err as Error
      console.error(`Service init failed: ${e.message}`)
    }
  }

  private async checkFirstLaunch(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext()
      if (!hostContext) { return }
      const context = hostContext as common.UIAbilityContext
      const pref = await preferences.getPreferences(context, 'diting_onboarding')
      const launched = await pref.get('has_launched', false) as boolean
      if (!launched) {
        this.showOnboarding = true
        await pref.put('has_launched', true)
        await pref.flush()
      }
    } catch (err) {
      const e = err as Error
      console.error(`Check first launch failed: ${e.message}`)
    }
  }

  private checkIncomingUrl(): void {
    try {
      const url = AppStorage.get<string>('incoming_url')
      if (url && url.length > 0) {
        AppStorage.setOrCreate('incoming_url', '')
        setTimeout(() => {
          this.sendMessage(`帮我检测这个链接的安全性：${url}`)
        }, 500)
        return
      }
      const text = AppStorage.get<string>('incoming_text')
      if (text && text.length > 0) {
        AppStorage.setOrCreate('incoming_text', '')
        setTimeout(() => {
          this.sendMessage(text)
        }, 500)
      }
    } catch (_err) {
      // ignore
    }
  }

  private async requestPermissionAndMonitor(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext()
      if (!hostContext) {
        return
      }
      const context = hostContext as common.UIAbilityContext
      const atManager = abilityAccessCtrl.createAtManager()
      const grantStatus = await atManager.checkAccessToken(
        context.applicationInfo.accessTokenId,
        READ_PASTEBOARD_PERMISSION
      )

      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        this.activateMonitor()
        this.requestNotificationPermission()
        this.requestLocationPermission()
        this.requestBluetoothPermission()
        return
      }

      const result = await atManager.requestPermissionsFromUser(
        context,
        [READ_PASTEBOARD_PERMISSION]
      )
      if (result.authResults[0] === 0) {
        this.activateMonitor()
        this.requestNotificationPermission()
        this.requestLocationPermission()
        this.requestBluetoothPermission()
      }
    } catch (err) {
      const e = err as Error
      console.error(`Permission request failed: ${e.message}`)
    }
  }

  private async requestLocationPermission(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext()
      if (!hostContext) { return }
      const context = hostContext as common.UIAbilityContext
      const atManager = abilityAccessCtrl.createAtManager()
      const grantStatus = await atManager.checkAccessToken(
        context.applicationInfo.accessTokenId,
        APPROXIMATELY_LOCATION_PERMISSION
      )
      if (grantStatus !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        await atManager.requestPermissionsFromUser(context, [APPROXIMATELY_LOCATION_PERMISSION])
      }
    } catch (_err) {
    }
  }

  private async requestBluetoothPermission(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext()
      if (!hostContext) { return }
      const context = hostContext as common.UIAbilityContext
      const atManager = abilityAccessCtrl.createAtManager()
      const grantStatus = await atManager.checkAccessToken(
        context.applicationInfo.accessTokenId,
        ACCESS_BLUETOOTH_PERMISSION
      )
      if (grantStatus !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        await atManager.requestPermissionsFromUser(context, [ACCESS_BLUETOOTH_PERMISSION])
      }
    } catch (_err) {
    }
  }

  private async requestNotificationPermission(): Promise<void> {
    try {
      const hostContext = this.getUIContext().getHostContext()
      if (!hostContext) { return }
      const context = hostContext as common.UIAbilityContext
      const enabled = await notificationManager.isNotificationEnabled()
      if (!enabled) {
        await notificationManager.requestEnableNotification(context)
      }
    } catch (_err) {
      // notification permission is optional
    }
  }

  private activateMonitor(): void {
    initMonitorOrchestrator((message: string, riskLevel: RiskLevel, _toolName: string) => {
      const alertMsg = new ChatMessage(this.nextId++, MessageRole.SYSTEM, message)
      alertMsg.riskLevel = riskLevel
      this.chatList = this.chatList.concat([alertMsg])
      this.showWelcome = false
      this.showDashboard = false

      if (riskLevel === RiskLevel.DANGEROUS || riskLevel === RiskLevel.CRITICAL) {
        sendSecurityAlert(formatAlertTitle(riskLevel), message.substring(0, 100), riskLevel)
        triggerHaptic(riskLevel)
      } else if (riskLevel === RiskLevel.SUSPICIOUS) {
        triggerHaptic(RiskLevel.SUSPICIOUS)
      }

      setTimeout(() => {
        this.listScroller.scrollEdge(Edge.Bottom)
      }, 100)
    })

    startClipboardMonitor((url: string, agentMsg: ChatMessage) => {
      const sysMsg = new ChatMessage(this.nextId++, MessageRole.SYSTEM,
        '📋 检测到你复制了一个链接，正在自动检测...')
      this.chatList = this.chatList.concat([sysMsg, agentMsg])
      this.showWelcome = false
      this.showDashboard = false

      setTimeout(() => {
        this.listScroller.scrollEdge(Edge.Bottom)
      }, 100)
    })
    this.monitorActive = isMonitoring()

    startNetworkWatch((message: string) => {
      const netMsg = new ChatMessage(this.nextId++, MessageRole.SYSTEM, message)
      this.chatList = this.chatList.concat([netMsg])
      this.showWelcome = false

      setTimeout(() => {
        this.listScroller.scrollEdge(Edge.Bottom)
      }, 100)
    })
    this.netWatchActive = isNetworkWatching()

    startAppLifecycleMonitor()
    this.appLifecycleActive = isAppLifecycleMonitoring()

    startBatteryUsbMonitor()
    this.batteryUsbActive = isBatteryUsbMonitoring()

    startBluetoothMonitor()
    this.bluetoothActive = isBluetoothMonitoring()

    startSimChangeMonitor()
    this.simChangeActive = isSimChangeMonitoring()
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
        Column() {
          if (this.showWelcome && this.showDashboard) {
            this.WelcomeSection()
            this.DashboardSection()
          }
          this.MessageList()
          this.QuickActions()
          this.InputBar()
        }
        .constraintSize({ maxWidth: 860 })
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 68 })
      .backgroundColor($r('app.color.page_bg'))

      if (this.showOnboarding) {
        OnboardingGuide({
          showOnboarding: this.showOnboarding,
          onClose: () => {
            this.showOnboarding = false
          },
          onEnableMonitor: () => {
            this.requestPermissionAndMonitor()
          }
        })
      }

      if (this.showScrollFab) {
        Row() {
          Text('↓')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.accent_blue'))
        .shadow({ radius: 8, color: $r('app.color.accent_blue_border'), offsetY: 2 })
        .justifyContent(FlexAlign.Center)
        .position({ x: '82%', y: '78%' })
        .onClick(() => {
          this.listScroller.scrollEdge(Edge.Bottom)
          this.showScrollFab = false
        })
        .transition({ type: TransitionType.Insert, opacity: 0, scale: { x: 0.5, y: 0.5 } })
        .transition({ type: TransitionType.Delete, opacity: 0, scale: { x: 0.5, y: 0.5 } })
      }

      Column() {
        this.TitleBar()
      }
      .width('100%')
      .constraintSize({ maxWidth: 860 })
      .hitTestBehavior(HitTestMode.Default)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TitleBar() {
    Row() {
      Row() {
        Text(this.monitorActive ? '🛡️' : '⚠️')
          .fontSize(20)
      }
      .width(40)
      .height(40)
      .borderRadius(12)
      .backgroundColor(this.monitorActive ? $r('app.color.accent_green_light') : $r('app.color.accent_orange_light'))
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text('谛听 · 安全守护')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
         Row() {
           Row()
             .width(6)
             .height(6)
             .borderRadius(3)
             .backgroundColor(this.monitorActive ? $r('app.color.accent_green') : $r('app.color.accent_orange'))
             .margin({ right: 4 })
           Text(this.getGuardStatusText())
             .fontSize(12)
             .fontColor($r('app.color.text_secondary'))
           Text(this.getScorePill())
             .fontSize(11)
             .fontColor(Color.White)
             .fontWeight(FontWeight.Bold)
             .padding({ left: 6, right: 6, top: 2, bottom: 2 })
             .borderRadius(6)
             .backgroundColor(this.getScorePillColor())
             .margin({ left: 6 })
         }
         .margin({ top: 4 })
       }
       .alignItems(HorizontalAlign.Start)
       .layoutWeight(1)

       Row() {
         Text('📊')
           .fontSize(16)
       }
       .width(36)
       .height(36)
       .borderRadius(18)
       .backgroundColor($r('app.color.page_bg'))
       .justifyContent(FlexAlign.Center)
       .margin({ right: 8 })
       .accessibilityText('切换仪表盘')
      .accessibilityLevel('important')
      .onClick(() => {
        this.showDashboard = !this.showDashboard
        if (this.showDashboard) {
          this.showWelcome = true
        }
      })

      Row() {
        Text('📜')
          .fontSize(16)
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor($r('app.color.page_bg'))
      .justifyContent(FlexAlign.Center)
       .margin({ right: 8 })
       .accessibilityText('安全记录')
      .accessibilityLevel('important')
      .onClick(() => {
        this.getUIContext().getRouter().pushUrl({
          url: 'pages/SecurityHistory'
        }, router.RouterMode.Standard)
      })

      Row() {
        Text('⚙️')
          .fontSize(16)
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor($r('app.color.page_bg'))
      .justifyContent(FlexAlign.Center)
       .margin({ right: 8 })
       .accessibilityText('设置')
      .accessibilityLevel('important')
      .onClick(() => {
        this.getUIContext().getRouter().pushUrl({
          url: 'pages/Settings'
        }, router.RouterMode.Standard)
      })

      Row() {
        if (this.monitorActive) {
          Text('📋')
            .fontSize(16)
        } else {
          Text('📋')
            .fontSize(16)
            .opacity(0.4)
        }
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor($r('app.color.chip_bg'))
      .justifyContent(FlexAlign.Center)
      .accessibilityText(this.monitorActive ? '停止守护' : '开启守护')
      .accessibilityLevel('important')
      .onClick(() => {
        if (this.monitorActive) {
          stopClipboardMonitor()
          stopNetworkWatch()
          stopAppLifecycleMonitor()
          stopBatteryUsbMonitor()
          stopBluetoothMonitor()
          stopSimChangeMonitor()
          destroyMonitorOrchestrator()
          this.monitorActive = false
          this.netWatchActive = false
          this.appLifecycleActive = false
          this.batteryUsbActive = false
          this.bluetoothActive = false
          this.simChangeActive = false
        } else {
          this.requestPermissionAndMonitor()
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
  }

  @Builder
  WelcomeSection() {
    Column() {
      Stack() {
        Column() {
          Text('🛡️')
            .fontSize(44)
        }
        .width(80)
        .height(80)
        .borderRadius(22)
        .backgroundColor($r('app.color.accent_green_light'))
        .justifyContent(FlexAlign.Center)
        .border({ width: 2, color: $r('app.color.accent_green_light'), radius: 22 })
        .translate({ y: this.shieldY })
        .animation({ duration: 1200, curve: Curve.EaseInOut })

        if (this.monitorActive) {
          Row()
            .width(14)
            .height(14)
            .borderRadius(7)
            .backgroundColor($r('app.color.accent_green'))
            .border({ width: 2, color: $r('app.color.card_bg'), radius: 7 })
            .position({ x: 62, y: 2 })
        }
      }
      .width(80)
      .height(80)
      .margin({ bottom: 16 })

      Text(APP_SLOGAN)
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })

      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        this.WelcomeChip('🔗', '链接检测', $r('app.color.accent_blue_light'), $r('app.color.accent_blue'))
        this.WelcomeChip('🔐', '权限分析', $r('app.color.accent_purple_light'), $r('app.color.accent_purple'))
        this.WelcomeChip('📁', '文件扫描', $r('app.color.accent_orange_light'), $r('app.color.accent_orange'))
        this.WelcomeChip('📶', 'Wi-Fi', $r('app.color.accent_green_light'), $r('app.color.accent_green'))
        this.WelcomeChip('🛡️', '隐私评分', $r('app.color.accent_violet_light'), $r('app.color.accent_violet'))
        this.WelcomeChip('📱', '设备监控', $r('app.color.accent_teal_light'), $r('app.color.accent_teal'))
      }
      .margin({ bottom: 8 })

       Text('所有安全分析均在设备端完成，绝不上传你的数据')
         .fontSize(11)
         .fontColor($r('app.color.text_tertiary'))
         .margin({ top: 4 })

      Row() {
        if (this.monitorActive) {
          Row() {
             Row()
               .width(6)
               .height(6)
               .borderRadius(3)
               .backgroundColor($r('app.color.accent_green'))
               .margin({ right: 4 })
             Text('6大守护已开启')
               .fontSize(11)
               .fontColor($r('app.color.accent_green'))
               .fontWeight(FontWeight.Medium)
           }
           .padding({ left: 12, right: 12, top: 4, bottom: 4 })
           .borderRadius(12)
           .backgroundColor($r('app.color.accent_green_light'))
         } else {
           Row() {
             Row()
               .width(6)
               .height(6)
               .borderRadius(3)
               .backgroundColor($r('app.color.accent_orange'))
               .margin({ right: 4 })
             Text('点击右上角 📋 开启守护')
               .fontSize(11)
               .fontColor($r('app.color.accent_orange'))
               .fontWeight(FontWeight.Medium)
           }
           .padding({ left: 12, right: 12, top: 4, bottom: 4 })
           .borderRadius(12)
           .backgroundColor($r('app.color.accent_orange_light'))
        }
       }
       .margin({ top: 8 })
       if (this.dailyTip.length > 0) {
         Column() {
           Row() {
             Text('💡')
               .fontSize(12)
               .margin({ right: 8 })
            Text(this.dailyTip)
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
              .lineHeight(16)
              .layoutWeight(1)
             Text('✕')
               .fontSize(11)
               .fontColor($r('app.color.text_tertiary'))
               .padding(8)
               .margin({ left: 4 })
               .onClick(() => { this.dailyTip = '' })
          }
        }
        .width('100%')
         .padding({ left: 12, right: 12, top: 8, bottom: 8 })
         .borderRadius(8)
         .backgroundColor($r('app.color.accent_yellow'))
         .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  WelcomeChip(icon: string, label: string, bg: ResourceColor, color: ResourceColor) {
    Row() {
      Text(icon)
        .fontSize(10)
      Text(label)
        .fontSize(10)
        .fontColor(color)
        .margin({ left: 2 })
    }
     .padding({ left: 8, right: 8, top: 4, bottom: 4 })
     .borderRadius(8)
     .backgroundColor(bg)
     .margin({ left: 4, right: 4, bottom: 4 })
  }

  @Builder
  DashboardSection() {
    Column() {
      SecurityDashboard()
    }
    .width('100%')
    .padding({ left: 16, right: 16, bottom: 12 })
    .transition({ type: TransitionType.Insert, opacity: 0, scale: { x: 0.95, y: 0.95 } })
    .transition({ type: TransitionType.Delete, opacity: 0, scale: { x: 0.95, y: 0.95 } })
  }

  @Builder
  MessageList() {
    if (this.chatList.length === 0) {
      Column() {
        Column() {
          Text('🛡️')
            .fontSize(48)
            .margin({ bottom: 16 })
           Text('谛听已就绪')
             .fontSize(18)
             .fontWeight(FontWeight.Medium)
             .fontColor($r('app.color.text_primary'))
             .margin({ bottom: 8 })
          Text('输入安全问题或粘贴链接开始检测')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      List({ scroller: this.listScroller, space: 4 }) {
        ForEach(this.chatList, (msg: ChatMessage, index: number) => {
          ListItem() {
            Column() {
              if (this.shouldShowTimeSeparator(index)) {
                this.TimeSeparator(msg.timestamp)
              }
              if (msg.role === MessageRole.SYSTEM) {
                this.SystemMessage(msg)
              } else {
                MessageBubble({ message: msg })
              }
            }
          }
          .transition({ type: TransitionType.Insert, opacity: 0, translate: { y: 12 } })
        }, (msg: ChatMessage) => msg.id.toString())
        if (this.isSending) {
          ListItem() {
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
                .backgroundColor($r('app.color.accent_blue'))
                .justifyContent(FlexAlign.Center)
                .margin({ right: 8 })
              }

              Row() {
                Row()
                  .width(6)
                  .height(6)
                  .borderRadius(3)
                  .backgroundColor($r('app.color.text_tertiary'))
                  .margin({ left: 2, right: 2 })
                Row()
                  .width(6)
                  .height(6)
                  .borderRadius(3)
                  .backgroundColor($r('app.color.text_tertiary'))
                  .margin({ left: 2, right: 2 })
                Row()
                  .width(6)
                  .height(6)
                  .borderRadius(3)
                  .backgroundColor($r('app.color.text_tertiary'))
                  .margin({ left: 2, right: 2 })
              }
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .borderRadius({ topLeft: 2, topRight: 16, bottomLeft: 16, bottomRight: 16 })
              .backgroundColor($r('app.color.card_bg'))
              .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: 1 })
            }
            .padding({ left: 16, right: 16, top: 4, bottom: 4 })
            .alignItems(VerticalAlign.Top)
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onDidScroll(() => {
        this.showScrollFab = !this.listScroller.isAtEnd()
      })
    }
  }

  @Builder
  SystemMessage(msg: ChatMessage) {
    Row() {
      Text(msg.content)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('85%')
    .justifyContent(FlexAlign.Center)
     .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .borderRadius(12)
    .backgroundColor($r('app.color.chip_bg'))
    .alignSelf(ItemAlign.Center)
  }

  @Builder
  TimeSeparator(timestamp: number) {
    Row() {
      Text(this.formatTimeSeparator(timestamp))
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
     .padding({ top: 8, bottom: 8 })
  }

  private shouldShowTimeSeparator(index: number): boolean {
    if (index === 0) {
      return true
    }
    const prev = this.chatList[index - 1]
    const curr = this.chatList[index]
    return curr.timestamp - prev.timestamp > 300000
  }

  private formatTimeSeparator(ts: number): string {
    const d = new Date(ts)
    const now = new Date()
    const h = d.getHours().toString().padStart(2, '0')
    const m = d.getMinutes().toString().padStart(2, '0')
    if (d.toDateString() === now.toDateString()) {
      return `今天 ${h}:${m}`
    }
    const month = (d.getMonth() + 1).toString()
    const day = d.getDate().toString()
    return `${month}月${day}日 ${h}:${m}`
  }

  @Builder
  QuickActions() {
    Column() {
      Row() {
        Text('快捷操作')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .fontWeight(FontWeight.Medium)
      }
      .margin({ bottom: 8 })

      QuickActionPanel({
        onAction: (action: string) => {
          triggerLightHaptic()
          this.sendMessage(action)
        }
      })
    }
    .width('100%')
     .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius({ topLeft: 16, topRight: 16 })
    .shadow({ radius: 4, color: $r('app.color.shadow_subtle'), offsetY: -1 })
  }

  @Builder
  InputBar() {
    Row() {
      Stack() {
        TextInput({ text: $$this.inputText, placeholder: '输入安全问题或粘贴链接...' })
          .layoutWeight(1)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('app.color.page_bg'))
          .padding({ left: 16, right: 40 })
          .fontSize(15)
          .placeholderColor($r('app.color.text_tertiary'))
          .placeholderFont({ size: 15 })
          .enabled(!this.isSending)
          .onSubmit(() => {
            this.sendMessage(this.inputText)
          })
         Row() {
           Text('📋')
             .fontSize(13)
         }
         .width(36)
         .height(36)
         .borderRadius(18)
         .justifyContent(FlexAlign.Center)
         .align(Alignment.End)
         .margin({ right: 8 })
        .onClick(() => { this.pasteFromClipboard() })
        .accessibilityText('粘贴')
        .accessibilityLevel('auto')
      }
      .layoutWeight(1)

      if (this.isSending) {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(Color.White)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('app.color.accent_blue'))
        .justifyContent(FlexAlign.Center)
        .margin({ left: 8 })
      } else {
        Row() {
          Text('↑')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor(this.inputText.trim().length > 0 ? $r('app.color.accent_blue') : $r('app.color.text_tertiary'))
        .justifyContent(FlexAlign.Center)
        .margin({ left: 8 })
        .enabled(this.inputText.trim().length > 0)
        .accessibilityText('发送消息')
        .accessibilityLevel('important')
        .onClick(() => {
          this.sendMessage(this.inputText)
        })
      }
    }
    .width('100%')
     .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.card_bg'))
    .alignItems(VerticalAlign.Center)
  }

  private sendMessage(text: string): void {
    const trimmed = text.trim()
    if (trimmed.length === 0 || this.isSending) {
      return
    }
    this.isSending = true
    this.inputText = ''
    this.showWelcome = false
    this.showDashboard = false

    const userMsg = new ChatMessage(this.nextId++, MessageRole.USER, trimmed)
    this.chatList = this.chatList.concat([userMsg])

    setTimeout(() => {
      this.listScroller.scrollEdge(Edge.Bottom)
    }, 50)

    setTimeout(() => {
      try {
        const newMessages = processUserInput(trimmed, this.chatList)
        const agentMsg = newMessages.length > 1 ? newMessages[newMessages.length - 1] : null
        if (agentMsg) {
          this.chatList = this.chatList.concat([agentMsg])
        }

        setTimeout(() => {
          this.listScroller.scrollEdge(Edge.Bottom)
        }, 50)

        if (agentMsg && agentMsg.role === MessageRole.AGENT &&
          (agentMsg.riskLevel === RiskLevel.DANGEROUS || agentMsg.riskLevel === RiskLevel.CRITICAL)) {
          sendSecurityAlert(
            formatAlertTitle(agentMsg.riskLevel),
            agentMsg.content.substring(0, 100),
            agentMsg.riskLevel
          )
          triggerHaptic(agentMsg.riskLevel)
        } else if (agentMsg && agentMsg.role === MessageRole.AGENT &&
          agentMsg.riskLevel === RiskLevel.SUSPICIOUS) {
          triggerHaptic(RiskLevel.SUSPICIOUS)
        }

        const toolName = this.getToolName(trimmed)
        const toolTarget = this.getToolTarget(trimmed)
        if (toolName.length > 0 && agentMsg) {
          addSecurityRecord(toolName, agentMsg.riskLevel, agentMsg.content.substring(0, 100), toolTarget)
        }
      } finally {
        this.isSending = false
      }
    }, 600)
  }

  private getToolName(input: string): string {
    const lower = input.toLowerCase()
    if (lower.indexOf('http://') >= 0 || lower.indexOf('https://') >= 0 || lower.indexOf('链接') >= 0) { return 'link_check' }
    if (lower.indexOf('权限') >= 0) { return 'permission_scan' }
    if (lower.indexOf('文件') >= 0 || lower.indexOf('扫描') >= 0) { return 'file_scan' }
    if (lower.indexOf('网络') >= 0) { return 'network_monitor' }
    if (lower.indexOf('全面') >= 0 || lower.indexOf('体检') >= 0 || lower.indexOf('隐私') >= 0) { return 'privacy_health_check' }
    if (lower.indexOf('wifi') >= 0 || lower.indexOf('wi-fi') >= 0) { return 'wifi_check' }
    if (lower.indexOf('报告') >= 0) { return 'security_report' }
    if (lower.indexOf('设备') >= 0 || lower.indexOf('守护状态') >= 0 || lower.indexOf('监控状态') >= 0) { return 'device_security_check' }
    return ''
  }

  private getToolTarget(input: string): string {
    const urlMatch = input.match(new RegExp('https?:\\/\\/[^\\s<>"{}|\\\\^`[\\]]+'))
    if (urlMatch) { return urlMatch[0] }
    return ''
  }

  private pasteFromClipboard(): void {
    try {
      const sysPasteboard = pasteboard.getSystemPasteboard()
      sysPasteboard.getData().then((data: pasteboard.PasteData) => {
        const text = data.getPrimaryText()
        if (text.length > 0) {
          if (text.length <= 500) {
            this.inputText = text
          }
        }
      }).catch(() => {})
    } catch (_err) {
      // ignore
    }
  }

  private getGuardStatusText(): string {
    const activeCount = getActiveMonitorCount()
    if (activeCount >= 6) {
      return '6大守护运行中'
    } else if (activeCount > 0) {
      return `${activeCount}个守护运行中`
    }
    return '点击开启守护'
  }

  private getScorePill(): string {
    const stats = getHistoryStats()
    const params = new SecurityScoreParams()
    params.totalChecks = stats.total
    params.dangerousCount = stats.dangerousCount
    params.suspiciousCount = stats.suspiciousCount
    params.anyMonitorActive = this.monitorActive || this.netWatchActive || this.appLifecycleActive ||
      this.batteryUsbActive || this.bluetoothActive || this.simChangeActive
    const score = calcSecurityScore(params)
    return `${score}`
  }

  private getScorePillColor(): ResourceColor {
    const stats = getHistoryStats()
    const params = new SecurityScoreParams()
    params.totalChecks = stats.total
    params.dangerousCount = stats.dangerousCount
    params.suspiciousCount = stats.suspiciousCount
    params.anyMonitorActive = this.monitorActive || this.netWatchActive || this.appLifecycleActive ||
      this.batteryUsbActive || this.bluetoothActive || this.simChangeActive
    const score = calcSecurityScore(params)
    if (score >= 80) { return $r('app.color.risk_safe') }
    if (score >= 60) { return $r('app.color.risk_suspicious') }
    return $r('app.color.risk_dangerous')
  }
}
