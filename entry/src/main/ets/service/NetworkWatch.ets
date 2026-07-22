import { connection } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RiskLevel } from '../model/ChatModel'
import { sendSecurityAlert, formatAlertTitle } from './NotificationService'
import { addSecurityRecord } from './SecurityHistory'
import { checkWifiSecurity, WifiSecurityInfo } from './WifiSecurity'
import { setMonitorActive } from './MonitorOrchestrator'

const DOMAIN = 0xF000
const TAG = 'DiTingNetWatch'

class NetWatchState {
  isWatching: boolean = false
  lastWasSecure: boolean = true
  lastBearerType: string = ''
  netConn: connection.NetConnection | null = null
  onAlert: ((message: string) => void) | null = null
}

const state = new NetWatchState()

export function startNetworkWatch(callback: (message: string) => void): void {
  if (state.isWatching) {
    hilog.info(DOMAIN, TAG, 'Network watch already running')
    return
  }

  state.onAlert = callback
  state.isWatching = true

  try {
    state.netConn = connection.createNetConnection()

    state.netConn.on('netAvailable', (netHandle: connection.NetHandle) => {
      hilog.info(DOMAIN, TAG, `Network available: netId=${netHandle.netId}`)
      handleNetChange(netHandle, '网络已连接')
    })

    state.netConn.on('netLost', (netHandle: connection.NetHandle) => {
      hilog.info(DOMAIN, TAG, `Network lost: netId=${netHandle.netId}`)
      const msg = '⚠️ 网络连接已断开，请注意数据安全。'
      if (state.onAlert) {
        state.onAlert(msg)
      }
      state.lastBearerType = ''
    })

    state.netConn.on('netCapabilitiesChange', (data: connection.NetCapabilityInfo) => {
      hilog.info(DOMAIN, TAG, `Net capabilities changed: netId=${data.netHandle.netId}`)
      handleNetChange(data.netHandle, '网络状态变化')
    })

    state.netConn.register(() => {
      hilog.info(DOMAIN, TAG, 'Network watch registered')
    })

    setMonitorActive('network', true)
    hilog.info(DOMAIN, TAG, 'Network watch started')
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `startNetworkWatch failed: ${e.message}`)
    state.isWatching = false
  }
}

export function stopNetworkWatch(): void {
  if (!state.isWatching || !state.netConn) {
    return
  }

  try {
    state.netConn.unregister(() => {
      hilog.info(DOMAIN, TAG, 'Network watch unregistered')
    })
    state.isWatching = false
    state.onAlert = null
    state.netConn = null
    state.lastBearerType = ''
    setMonitorActive('network', false)
    hilog.info(DOMAIN, TAG, 'Network watch stopped')
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `stopNetworkWatch failed: ${e.message}`)
  }
}

export function isNetworkWatching(): boolean {
  return state.isWatching
}

export function getCurrentNetworkInfo(): string {
  try {
    const netHandle = connection.getDefaultNetSync()
    const netCap = connection.getNetCapabilitiesSync(netHandle)
    const bearerTypes = netCap.bearerTypes
    const networkCap = netCap.networkCap || []
    const isWifi = bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0
    const isCellular = bearerTypes.indexOf(connection.NetBearType.BEARER_CELLULAR) >= 0
    const isEthernet = bearerTypes.indexOf(connection.NetBearType.BEARER_ETHERNET) >= 0
    const isValidated = networkCap.indexOf(connection.NetCap.NET_CAPABILITY_VALIDATED) >= 0

    let typeStr = '未知'
    if (isWifi) { typeStr = 'Wi-Fi' }
    else if (isCellular) { typeStr = '蜂窝数据' }
    else if (isEthernet) { typeStr = '以太网' }

    const validated = isValidated ? '已验证' : '未验证'
    return `${typeStr} | ${validated}`
  } catch (err) {
    return '未连接'
  }
}

function getBearerTypeStr(bearerTypes: number[]): string {
  if (bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0) { return 'Wi-Fi' }
  if (bearerTypes.indexOf(connection.NetBearType.BEARER_CELLULAR) >= 0) { return '蜂窝数据' }
  if (bearerTypes.indexOf(connection.NetBearType.BEARER_ETHERNET) >= 0) { return '以太网' }
  return '未知'
}

function handleNetChange(netHandle: connection.NetHandle, eventDesc: string): void {
  try {
    // PERF: getNetCapabilitiesSync blocks the main thread; async API is preferred
    // but requires significant architectural changes to this callback-based design.
    const netCap = connection.getNetCapabilitiesSync(netHandle)
    const bearerTypes = netCap.bearerTypes
    const networkCap = netCap.networkCap || []
    const isValidated = networkCap.indexOf(connection.NetCap.NET_CAPABILITY_VALIDATED) >= 0
    const isPortal = networkCap.indexOf(connection.NetCap.NET_CAPABILITY_PORTAL) >= 0
    const isWifi = bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0

    const typeStr = getBearerTypeStr(bearerTypes)
    const typeChanged = state.lastBearerType.length > 0 && state.lastBearerType !== typeStr

    let isSecure = true
    let alertMsg = ''

    if (isPortal) {
      isSecure = false
      alertMsg = `🔴 检测到需要认证的公共 ${typeStr} 网络（Portal），可能存在安全风险！\n\n━━━━━━━\n💡 建议：不要在此网络输入密码/银行卡等敏感信息，必要时使用VPN加密。`
    } else if (!isValidated) {
      isSecure = false
      alertMsg = `🟡 当前 ${typeStr} 网络未经验证，可能无法正常访问互联网。\n\n━━━━━━━\n💡 建议：等待网络验证完成，或切换到可信网络。`
    } else if (isWifi) {
      const wifiInfo: WifiSecurityInfo = checkWifiSecurity()
      if (wifiInfo.riskLevel === RiskLevel.DANGEROUS) {
        isSecure = false
        alertMsg = `🔴 当前 Wi-Fi "${wifiInfo.ssid}" ${wifiInfo.securityType}，不安全！\n\n${wifiInfo.summary}\n\n━━━━━━━\n💡 建议：立即断开此Wi-Fi，切换到蜂窝数据或使用VPN。`
      } else if (typeChanged && state.lastBearerType === '蜂窝数据' && isWifi) {
        if (wifiInfo.riskLevel === RiskLevel.SAFE) {
          const safeMsg = `🟢 已从蜂窝数据切换到安全 Wi-Fi "${wifiInfo.ssid}"（${wifiInfo.securityType}），连接安全。`
          if (state.onAlert) {
            state.onAlert(safeMsg)
          }
        }
      }
    }

    if (typeChanged && state.lastBearerType === 'Wi-Fi' && getBearerTypeStr(bearerTypes) === '蜂窝数据') {
      const infoMsg = `📱 已从 Wi-Fi 切换到蜂窝数据，连接安全。`
      if (state.onAlert && !alertMsg) {
        state.onAlert(infoMsg)
      }
    }

    if (!isSecure && state.lastWasSecure) {
      if (state.onAlert) {
        state.onAlert(alertMsg)
      }
      sendSecurityAlert(formatAlertTitle(RiskLevel.SUSPICIOUS), alertMsg.substring(0, 100), RiskLevel.SUSPICIOUS)
      addSecurityRecord('network_monitor', RiskLevel.SUSPICIOUS, alertMsg.substring(0, 100),
        `${typeStr} Portal/unvalidated/insecure`)
    } else if (isSecure && !state.lastWasSecure) {
      const safeMsg = `🟢 网络已恢复安全连接（${typeStr}），可以正常使用。`
      if (state.onAlert) {
        state.onAlert(safeMsg)
      }
    }

    state.lastWasSecure = isSecure
    state.lastBearerType = typeStr
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `handleNetChange error: ${e.message}`)
  }
}
