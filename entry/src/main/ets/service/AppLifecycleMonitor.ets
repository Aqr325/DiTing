import { commonEventManager } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RiskLevel } from '../model/ChatModel'
import { reportAlert, setMonitorActive } from './MonitorOrchestrator'
import { sendSecurityAlert, formatAlertTitle } from './NotificationService'

const DOMAIN = 0xF000
const TAG = 'DiTingAppMonitor'

const SECURITY_APP_PACKAGES: string[] = [
  'com.diting.agent',
  'com.huawei.securitymanager',
  'com.huawei.hiai',
  'com.huawei.systemmanager'
]

const HIGH_RISK_PACKAGES: string[] = [
  'com.remote.control',
  'com.spy.monitor',
  'com.keylogger',
  'com.tracker.gps'
]

class AppMonitorState {
  subscriber: commonEventManager.CommonEventSubscriber | null = null
  isRunning: boolean = false
}

const state = new AppMonitorState()

export function startAppLifecycleMonitor(): void {
  if (state.isRunning) {
    return
  }

  try {
    const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
      events: [
        commonEventManager.Support.COMMON_EVENT_PACKAGE_ADDED,
        commonEventManager.Support.COMMON_EVENT_PACKAGE_REMOVED,
        commonEventManager.Support.COMMON_EVENT_PACKAGE_REPLACED
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
        const event = data.event ?? ''
        const pkgData = data.data ?? ''
        handlePackageEvent(event, pkgData)
      })

      state.isRunning = true
      setMonitorActive('app_lifecycle', true)
      hilog.info(DOMAIN, TAG, 'App lifecycle monitor started')
    })
  } catch (err) {
    hilog.error(DOMAIN, TAG, `Start app monitor failed: ${(err as Error).message}`)
  }
}

export function stopAppLifecycleMonitor(): void {
  if (!state.isRunning || !state.subscriber) {
    return
  }

  try {
    commonEventManager.unsubscribe(state.subscriber, () => {
      hilog.info(DOMAIN, TAG, 'App lifecycle monitor stopped')
    })
  } catch (err) {
    hilog.error(DOMAIN, TAG, `Unsubscribe failed: ${(err as Error).message}`)
  }

  state.subscriber = null
  state.isRunning = false
  setMonitorActive('app_lifecycle', false)
}

export function isAppLifecycleMonitoring(): boolean {
  return state.isRunning
}

function handlePackageEvent(event: string, pkgName: string): void {
  if (event === commonEventManager.Support.COMMON_EVENT_PACKAGE_ADDED) {
    hilog.info(DOMAIN, TAG, `Package added: ${pkgName}`)

    let isHighRisk = false
    for (const riskPkg of HIGH_RISK_PACKAGES) {
      if (pkgName.indexOf(riskPkg) >= 0) {
        isHighRisk = true
        break
      }
    }

    if (isHighRisk) {
      const msg = `🔴 检测到高风险应用安装：${pkgName}\n\n该应用可能存在安全风险，建议立即卸载。\n\n━━━━━━━\n💡 建议：前往系统设置→应用管理，检查该应用的权限并考虑卸载。`
      reportAlert(msg, RiskLevel.DANGEROUS, 'app_lifecycle')
      sendSecurityAlert(formatAlertTitle(RiskLevel.DANGEROUS), msg.substring(0, 100), RiskLevel.DANGEROUS)
    } else {
      const msg = `🟡 检测到新应用安装：${pkgName}\n\n建议检查新应用的权限设置，确保不会过度索取敏感权限。\n\n━━━━━━━\n💡 建议：在系统设置中审查该应用的权限，关闭不必要的敏感权限（位置、通讯录、相机等）。`
      reportAlert(msg, RiskLevel.SUSPICIOUS, 'app_lifecycle')
    }
  } else if (event === commonEventManager.Support.COMMON_EVENT_PACKAGE_REMOVED) {
    hilog.info(DOMAIN, TAG, `Package removed: ${pkgName}`)

    let isSecurityApp = false
    for (const secPkg of SECURITY_APP_PACKAGES) {
      if (pkgName === secPkg) {
        isSecurityApp = true
        break
      }
    }

    if (isSecurityApp) {
      const msg = `🔴 安全相关应用被卸载：${pkgName}\n\n安全类应用被移除可能影响设备防护能力，请确认是否为本人操作。\n\n━━━━━━━\n💡 建议：重新安装安全应用，确保设备持续受到保护。`
      reportAlert(msg, RiskLevel.DANGEROUS, 'app_lifecycle')
      sendSecurityAlert(formatAlertTitle(RiskLevel.DANGEROUS), msg.substring(0, 100), RiskLevel.DANGEROUS)
    } else {
      const msg = `📱 应用已卸载：${pkgName}`
      reportAlert(msg, RiskLevel.SAFE, 'app_lifecycle')
    }
  } else if (event === commonEventManager.Support.COMMON_EVENT_PACKAGE_REPLACED) {
    hilog.info(DOMAIN, TAG, `Package replaced: ${pkgName}`)
    const msg = `🟢 应用已更新：${pkgName}\n\n应用更新通常包含安全补丁，建议保持应用为最新版本。`
    reportAlert(msg, RiskLevel.SAFE, 'app_lifecycle')
  }
}
