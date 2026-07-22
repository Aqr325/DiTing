import { commonEventManager } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RiskLevel } from '../model/ChatModel'
import { reportAlert, setMonitorActive } from './MonitorOrchestrator'
import { sendSecurityAlert, formatAlertTitle } from './NotificationService'

const DOMAIN = 0xF000
const TAG = 'DiTingSimMonitor'
const SIM_STATE_ABSENT = 0
const SIM_STATE_NOT_READY = 1
const SIM_STATE_LOCKED = 2
const SIM_STATE_READY = 5

class SimMonitorState {
  subscriber: commonEventManager.CommonEventSubscriber | null = null
  isRunning: boolean = false
  lastSimState: number = -1
  simRemovedAt: number = 0
}

const state = new SimMonitorState()

export function startSimChangeMonitor(): void {
  if (state.isRunning) {
    return
  }

  try {
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [
        commonEventManager.Support.COMMON_EVENT_SIM_STATE_CHANGED
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

        handleSimStateChange(data.code ?? 0)
      })

      state.isRunning = true
      setMonitorActive('sim', true)
      hilog.info(DOMAIN, TAG, 'SIM change monitor started')
    })
  } catch (err) {
    hilog.error(DOMAIN, TAG, `Start SIM monitor failed: ${(err as Error).message}`)
  }
}

export function stopSimChangeMonitor(): void {
  if (!state.isRunning) {
    return
  }

  if (state.subscriber) {
    try {
      commonEventManager.unsubscribe(state.subscriber, () => {
        hilog.info(DOMAIN, TAG, 'SIM change monitor stopped')
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Unsubscribe failed: ${(err as Error).message}`)
    }
    state.subscriber = null
  }

  state.isRunning = false
  state.lastSimState = -1
  setMonitorActive('sim', false)
}

export function isSimChangeMonitoring(): boolean {
  return state.isRunning
}

function handleSimStateChange(code: number): void {
  hilog.info(DOMAIN, TAG, `SIM state changed: ${code}`)

  if (code === SIM_STATE_ABSENT) {
    state.simRemovedAt = Date.now()
    const msg = `🔴 SIM卡已移除！\n\n⚠️ 如非本人操作，你的手机号码可能正在被转移！\n\nSIM卡移除可能是SIM swap攻击的第一步：\n1. 取出你的SIM卡\n2. 将你的号码复制到攻击者的SIM卡\n3. 接收你的短信验证码\n4. 盗取你的银行/社交账户\n\n━━━━━━━\n💡 紧急建议：\n- 确认手机是否在自己身边\n- 立即联系运营商冻结号码\n- 开启非短信方式的2FA（如认证器App）\n- 检查银行账户异常交易`
    reportAlert(msg, RiskLevel.CRITICAL, 'sim')
    sendSecurityAlert(formatAlertTitle(RiskLevel.CRITICAL), 'SIM卡已移除，可能遭遇SIM swap攻击', RiskLevel.CRITICAL)
  } else if (code === SIM_STATE_NOT_READY) {
    const msg = `🟡 SIM卡状态异常\n\nSIM卡未就绪，可能是：\n- SIM卡正在初始化\n- SIM卡接触不良\n- SIM卡被更换\n\n━━━━━━━\n💡 请确认SIM卡是否为本人操作更换。`
    reportAlert(msg, RiskLevel.SUSPICIOUS, 'sim')
  } else if (code === SIM_STATE_READY) {
    if (state.simRemovedAt > 0 && (Date.now() - state.simRemovedAt) < 60000) {
      const msg = `🔴 SIM卡已更换！\n\nSIM卡在短时间内被移除后又就绪，很可能是被替换为另一张SIM卡。\n\n⚠️ SIM swap诈骗风险极高！\n\n━━━━━━━\n💡 紧急操作：\n1. 立即联系运营商确认SIM卡状态\n2. 修改重要账户密码\n3. 冻结银行账户\n4. 开用认证器App替代短信验证码`
      reportAlert(msg, RiskLevel.CRITICAL, 'sim')
      sendSecurityAlert(formatAlertTitle(RiskLevel.CRITICAL), 'SIM卡已更换，疑似SIM swap攻击', RiskLevel.CRITICAL)
      state.simRemovedAt = 0
    } else if (state.lastSimState === SIM_STATE_NOT_READY) {
      const msg = `🟢 SIM卡已就绪\n\nSIM卡状态恢复正常。`
      reportAlert(msg, RiskLevel.SAFE, 'sim')
    }
  } else if (code === SIM_STATE_LOCKED) {
    const msg = `🟡 SIM卡已锁定\n\nSIM卡PIN码锁定，需要输入PUK码解锁。\n\n━━━━━━━\n💡 多次输入错误PIN码会导致锁定，请联系运营商获取PUK码。`
    reportAlert(msg, RiskLevel.SUSPICIOUS, 'sim')
  }

  state.lastSimState = code
}
