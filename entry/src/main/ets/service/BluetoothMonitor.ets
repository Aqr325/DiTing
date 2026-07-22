import { connection, constant } from '@kit.ConnectivityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RiskLevel } from '../model/ChatModel'
import { reportAlert, setMonitorActive } from './MonitorOrchestrator'
import { sendSecurityAlert, formatAlertTitle } from './NotificationService'

const DOMAIN = 0xF000
const TAG = 'DiTingBtMonitor'
const CHECK_INTERVAL_MS = 30000
const BT_ON_WARN_MS = 1800000

const PROFILE_A2DP: constant.ProfileId = constant.ProfileId.PROFILE_A2DP_SOURCE
const PROFILE_HFP: constant.ProfileId = constant.ProfileId.PROFILE_HANDSFREE_AUDIO_GATEWAY
const STATE_CONNECTED: constant.ProfileConnectionState = constant.ProfileConnectionState.STATE_CONNECTED

class BluetoothMonitorState {
  isRunning: boolean = false
  pairedBaseline: string[] = []
  checkTimer: number = -1
  btOnSince: number = 0
}

const state = new BluetoothMonitorState()

export function startBluetoothMonitor(): void {
  if (state.isRunning) {
    return
  }

  try {
    state.pairedBaseline = getPairedDeviceList()

    try {
      connection.on('bondStateChange', (data: connection.BondStateParam) => {
        handleBondStateChange(data)
      })
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `bondStateChange subscribe skipped: ${(err as Error).message}`)
    }

    state.btOnSince = Date.now()

    state.checkTimer = setInterval(() => {
      checkBluetoothStatus()
    }, CHECK_INTERVAL_MS)

    state.isRunning = true
    setMonitorActive('bluetooth', true)
    hilog.info(DOMAIN, TAG, 'Bluetooth monitor started')
  } catch (err) {
    hilog.error(DOMAIN, TAG, `Start BT monitor failed: ${(err as Error).message}`)
  }
}

export function stopBluetoothMonitor(): void {
  if (!state.isRunning) {
    return
  }

  if (state.checkTimer >= 0) {
    clearInterval(state.checkTimer)
    state.checkTimer = -1
  }

  try {
    connection.off('bondStateChange')
  } catch (_err) {
  }

  state.isRunning = false
  state.pairedBaseline = []
  setMonitorActive('bluetooth', false)
  hilog.info(DOMAIN, TAG, 'Bluetooth monitor stopped')
}

export function isBluetoothMonitoring(): boolean {
  return state.isRunning
}

export function getBluetoothStatus(): string {
  try {
    const paired = getPairedDeviceList()
    const a2dpState = connection.getProfileConnectionState(PROFILE_A2DP)
    const hfpState = connection.getProfileConnectionState(PROFILE_HFP)
    const isConnected = a2dpState === STATE_CONNECTED || hfpState === STATE_CONNECTED
    return `蓝牙: ${isConnected ? '已连接' : '未连接'} | 已配对设备: ${paired.length}个`
  } catch (err) {
    return '蓝牙: 无法获取状态'
  }
}

function getPairedDeviceList(): string[] {
  try {
    return connection.getPairedDevices()
  } catch (err) {
    hilog.warn(DOMAIN, TAG, `Get paired devices failed: ${(err as Error).message}`)
    return []
  }
}

function handleBondStateChange(data: connection.BondStateParam): void {
  const deviceId = data.deviceId

  if (data.state === connection.BondState.BOND_STATE_BONDING) {
    const msg = `🟡 检测到蓝牙设备正在配对\n\n设备地址：${maskDeviceId(deviceId)}\n\n━━━━━━━\n💡 如非本人操作，请在系统蓝牙设置中取消配对。`
    reportAlert(msg, RiskLevel.SUSPICIOUS, 'bluetooth')
  } else if (data.state === connection.BondState.BOND_STATE_BONDED) {
    let isKnown = false
    for (const known of state.pairedBaseline) {
      if (known === deviceId) {
        isKnown = true
        break
      }
    }

    if (!isKnown) {
      const msg = `🔴 新蓝牙设备配对成功\n\n设备地址：${maskDeviceId(deviceId)}\n\n⚠️ 如非本人操作，请立即在蓝牙设置中断开并取消配对！\n\n━━━━━━━\n💡 陌生设备配对可能导致数据泄露，建议立即检查。`
      reportAlert(msg, RiskLevel.DANGEROUS, 'bluetooth')
      sendSecurityAlert(formatAlertTitle(RiskLevel.DANGEROUS), `新蓝牙设备配对：${maskDeviceId(deviceId)}`, RiskLevel.DANGEROUS)
      state.pairedBaseline.push(deviceId)
    } else {
      const msg = `🟢 已知蓝牙设备已重新配对\n\n设备地址：${maskDeviceId(deviceId)}`
      reportAlert(msg, RiskLevel.SAFE, 'bluetooth')
    }
  }
}

function checkBluetoothStatus(): void {
  try {
    const a2dpState = connection.getProfileConnectionState(PROFILE_A2DP)
    const hfpState = connection.getProfileConnectionState(PROFILE_HFP)
    const isConnected = a2dpState === STATE_CONNECTED || hfpState === STATE_CONNECTED

    if (!isConnected && state.btOnSince > 0) {
      const duration = Date.now() - state.btOnSince
      if (duration > BT_ON_WARN_MS) {
        const msg = `🟡 蓝牙已开启超过30分钟但未使用\n\n长时间开启蓝牙会增加被攻击的风险。\n\n━━━━━━━\n💡 建议：不使用蓝牙时关闭，减少攻击面。`
        reportAlert(msg, RiskLevel.SUSPICIOUS, 'bluetooth')
        state.btOnSince = Date.now()
      }
    }

    if (isConnected) {
      state.btOnSince = 0
    }
  } catch (err) {
    hilog.warn(DOMAIN, TAG, `BT status check failed: ${(err as Error).message}`)
  }
}

function maskDeviceId(id: string): string {
  if (id.length <= 8) {
    return id
  }
  return id.substring(0, 4) + ':XX:XX:' + id.substring(id.length - 4)
}
