import { commonEventManager, batteryInfo } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RiskLevel } from '../model/ChatModel'
import { reportAlert, setMonitorActive } from './MonitorOrchestrator'
import { sendSecurityAlert, formatAlertTitle } from './NotificationService'

const DOMAIN = 0xF000
const TAG = 'DiTingBatUsb'
const DRAIN_SAMPLE_MS = 300000
const DRAIN_THRESHOLD_IDLE = 3
const DRAIN_THRESHOLD_SCREEN_OFF = 2
const TEMP_THRESHOLD = 400

class BatteryUsbState {
  subscriber: commonEventManager.CommonEventSubscriber | null = null
  isRunning: boolean = false
  lastSoc: number = -1
  sampleTimer: number = -1
}

const state = new BatteryUsbState()

export function startBatteryUsbMonitor(): void {
  if (state.isRunning) {
    return
  }

  try {
    state.lastSoc = batteryInfo.batterySOC

    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [
        commonEventManager.Support.COMMON_EVENT_BATTERY_CHANGED,
        commonEventManager.Support.COMMON_EVENT_POWER_CONNECTED,
        commonEventManager.Support.COMMON_EVENT_POWER_DISCONNECTED,
        commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
        commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED
      ]
    }

    commonEventManager.createSubscriber(subscribeInfo, (err, subscriber) => {
      if (err) {
        hilog.error(DOMAIN, TAG, `Create subscriber failed: ${err.message}`)
        return
      }

      state.subscriber = subscriber

      commonEventManager.subscribe(subscriber, (err, data) => {
        if (err) {
          hilog.error(DOMAIN, TAG, `Subscribe error: ${err.message}`)
          return
        }
        if (!data) {
          return
        }
        handleBatteryUsbEvent(data.event ?? '', data.code ?? 0)
      })

      state.isRunning = true
      setMonitorActive('battery_usb', true)
      hilog.info(DOMAIN, TAG, 'Battery/USB monitor started')
    })

    state.sampleTimer = setInterval(() => {
      checkBatteryDrain()
    }, DRAIN_SAMPLE_MS)
  } catch (err) {
    hilog.error(DOMAIN, TAG, `Start battery monitor failed: ${(err as Error).message}`)
  }
}

export function stopBatteryUsbMonitor(): void {
  if (!state.isRunning) {
    return
  }

  if (state.sampleTimer >= 0) {
    clearInterval(state.sampleTimer)
    state.sampleTimer = -1
  }

  if (state.subscriber) {
    try {
      commonEventManager.unsubscribe(state.subscriber, () => {
        hilog.info(DOMAIN, TAG, 'Battery/USB monitor stopped')
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Unsubscribe failed: ${(err as Error).message}`)
    }
    state.subscriber = null
  }

  state.isRunning = false
  setMonitorActive('battery_usb', false)
}

export function isBatteryUsbMonitoring(): boolean {
  return state.isRunning
}

export function getBatteryInfo(): string {
  try {
    const soc = batteryInfo.batterySOC
    const charging = batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.ENABLE
    const plugged = getPluggedTypeName(batteryInfo.pluggedType)
    const temp = batteryInfo.batteryTemperature
    return `电量: ${soc}% | 充电: ${charging ? '是' : '否'} | 接入: ${plugged} | 温度: ${(temp / 10).toFixed(1)}°C`
  } catch (err) {
    return '无法获取电池信息'
  }
}

function checkBatteryDrain(): void {
  try {
    const currentSoc = batteryInfo.batterySOC
    const now = Date.now()
    const isCharging = batteryInfo.chargingStatus === batteryInfo.BatteryChargeState.ENABLE

    if (isCharging || state.lastSoc < 0) {
      state.lastSoc = currentSoc
      return
    }

    const drain = state.lastSoc - currentSoc

    if (drain >= DRAIN_THRESHOLD_IDLE) {
      const msg = `🔴 检测到异常耗电：5分钟内电量下降${drain}%\n\n当前电量：${currentSoc}%\n\n可能原因：\n- 恶意软件后台挖矿\n- 异常应用持续运行\n- 系统服务异常\n\n━━━━━━━\n💡 建议：检查最近安装的应用，查看系统设置→电池使用情况，找出耗电最高的应用。`
      reportAlert(msg, RiskLevel.DANGEROUS, 'battery_usb')
      sendSecurityAlert(formatAlertTitle(RiskLevel.DANGEROUS), `异常耗电：5分钟下降${drain}%`, RiskLevel.DANGEROUS)
    } else if (drain >= DRAIN_THRESHOLD_SCREEN_OFF) {
      const msg = `🟡 后台耗电偏高：5分钟内电量下降${drain}%\n\n当前电量：${currentSoc}%\n\n━━━━━━━\n💡 建议：查看电池使用情况，关闭不必要的后台应用。`
      reportAlert(msg, RiskLevel.SUSPICIOUS, 'battery_usb')
    }

    const temp = batteryInfo.batteryTemperature
    if (temp > TEMP_THRESHOLD) {
      const msg = `🟡 设备温度偏高：${(temp / 10).toFixed(1)}°C\n\n高温可能导致：\n- 后台进程异常运行\n- 充电时使用高性能应用\n- 环境温度过高\n\n━━━━━━━\n💡 建议：暂停高负载应用，如非充电状态持续高温请检查后台应用。`
      reportAlert(msg, RiskLevel.SUSPICIOUS, 'battery_usb')
    }

    state.lastSoc = currentSoc
  } catch (err) {
    hilog.error(DOMAIN, TAG, `Battery drain check failed: ${(err as Error).message}`)
  }
}

function handleBatteryUsbEvent(event: string, _code: number): void {
  if (event === commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED) {
    const msg = `🟡 USB设备已连接\n\n⚠️ 如使用公共充电桩，请选择「仅充电」模式，拒绝「信任此设备」或「传输文件」选项。\n\n━━━━━━━\n💡 充电桩可能读取手机数据或安装恶意软件。只充电不传数据最安全。`
    reportAlert(msg, RiskLevel.SUSPICIOUS, 'battery_usb')
  } else if (event === commonEventManager.Support.COMMON_EVENT_POWER_CONNECTED) {
    try {
      const pluggedType = batteryInfo.pluggedType
      if (pluggedType === batteryInfo.BatteryPluggedType.USB) {
        const msg = `🟡 通过USB接口充电\n\nUSB充电可能同时传输数据，如使用公共充电桩请注意安全。\n\n━━━━━━━\n💡 选择「仅充电」模式可防止数据被读取。`
        reportAlert(msg, RiskLevel.SUSPICIOUS, 'battery_usb')
      }
    } catch (_err) {
    }
  }
}

function getPluggedTypeName(pluggedType: batteryInfo.BatteryPluggedType): string {
  if (pluggedType === batteryInfo.BatteryPluggedType.AC) {
    return '交流电'
  }
  if (pluggedType === batteryInfo.BatteryPluggedType.USB) {
    return 'USB'
  }
  if (pluggedType === batteryInfo.BatteryPluggedType.WIRELESS) {
    return '无线'
  }
  return '未接入'
}
