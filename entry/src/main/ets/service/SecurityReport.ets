import { getHistoryStats, getRecentRecords, HistoryStats, SecurityRecord } from './SecurityHistory'
import { RiskLevel } from '../model/ChatModel'
import { checkWifiSecurity, WifiSecurityInfo } from './WifiSecurity'
import { getMonitorStatus } from './MonitorOrchestrator'
import { isNetworkWatching } from './NetworkWatch'
import { isAppLifecycleMonitoring } from './AppLifecycleMonitor'
import { isBatteryUsbMonitoring } from './BatteryUsbMonitor'
import { isBluetoothMonitoring } from './BluetoothMonitor'
import { isSimChangeMonitoring } from './SimChangeMonitor'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { APP_SLOGAN } from '../common/AppConstants'

const DOMAIN = 0xF000
const TAG = 'DiTingReport'

export class SecurityReport {
  generatedAt: number = 0
  overallScore: number = 100
  overallRiskLevel: RiskLevel = RiskLevel.SAFE
  networkSection: NetworkReportSection = new NetworkReportSection()
  permissionSection: PermissionReportSection = new PermissionReportSection()
  privacySection: PrivacyReportSection = new PrivacyReportSection()
  historySection: HistoryReportSection = new HistoryReportSection()
  recommendations: string[] = []
  summary: string = ''
}

class NetworkReportSection {
  wifiSsid: string = ''
  wifiSecurityType: string = ''
  wifiSignalQuality: string = ''
  isSecure: boolean = true
  riskLevel: RiskLevel = RiskLevel.SAFE
  details: string = ''
}

class PermissionReportSection {
  totalChecks: number = 0
  riskFound: number = 0
  details: string = ''
}

class PrivacyReportSection {
  clipboardMonitorOn: boolean = false
  networkWatchOn: boolean = false
  appLifecycleOn: boolean = false
  batteryUsbOn: boolean = false
  bluetoothOn: boolean = false
  simChangeOn: boolean = false
  activeMonitorCount: number = 0
  clipboardScore: number = 100
  details: string = ''
}

class HistoryReportSection {
  totalChecks: number = 0
  safeCount: number = 0
  suspiciousCount: number = 0
  dangerousCount: number = 0
  recentThreats: string[] = []
}

export function generateSecurityReport(): SecurityReport {
  const report = new SecurityReport()
  report.generatedAt = Date.now()

  const stats: HistoryStats = getHistoryStats()
  report.historySection.totalChecks = stats.total
  report.historySection.safeCount = stats.safeCount
  report.historySection.suspiciousCount = stats.suspiciousCount
  report.historySection.dangerousCount = stats.dangerousCount

  const recentRecords: SecurityRecord[] = getRecentRecords(20)
  for (const r of recentRecords) {
    if (r.riskLevel === RiskLevel.DANGEROUS || r.riskLevel === RiskLevel.CRITICAL) {
      report.historySection.recentThreats.push(`[${r.toolName}] ${r.target.substring(0, 30)}`)
    }
  }

  const wifiInfo: WifiSecurityInfo = checkWifiSecurity()
  report.networkSection.wifiSsid = wifiInfo.ssid
  report.networkSection.wifiSecurityType = wifiInfo.securityType
  report.networkSection.wifiSignalQuality = wifiInfo.signalQuality
  report.networkSection.isSecure = wifiInfo.riskLevel === RiskLevel.SAFE
  report.networkSection.riskLevel = wifiInfo.riskLevel
  report.networkSection.details = wifiInfo.summary

  report.permissionSection.totalChecks = stats.total
  report.permissionSection.riskFound = stats.suspiciousCount + stats.dangerousCount
  report.permissionSection.details = stats.dangerousCount > 0 ?
    `发现 ${stats.dangerousCount} 个高风险项需立即处理` : '权限状态正常'

  const clipboardOn = getMonitorStatus('clipboard').active
  const networkOn = isNetworkWatching()
  const appLifecycleOn = isAppLifecycleMonitoring()
  const batteryUsbOn = isBatteryUsbMonitoring()
  const bluetoothOn = isBluetoothMonitoring()
  const simChangeOn = isSimChangeMonitoring()
  const activeMonitorCount = (clipboardOn ? 1 : 0) + (networkOn ? 1 : 0) + (appLifecycleOn ? 1 : 0) +
    (batteryUsbOn ? 1 : 0) + (bluetoothOn ? 1 : 0) + (simChangeOn ? 1 : 0)
  report.privacySection.clipboardMonitorOn = clipboardOn
  report.privacySection.networkWatchOn = networkOn
  report.privacySection.appLifecycleOn = appLifecycleOn
  report.privacySection.batteryUsbOn = batteryUsbOn
  report.privacySection.bluetoothOn = bluetoothOn
  report.privacySection.simChangeOn = simChangeOn
  report.privacySection.activeMonitorCount = activeMonitorCount
  report.privacySection.clipboardScore = activeMonitorCount >= 4 ? 95 : activeMonitorCount >= 2 ? 75 : 55
  report.privacySection.details = activeMonitorCount >= 4 ?
    `${activeMonitorCount}/6 守护引擎已激活，设备受到全面保护` :
    `${activeMonitorCount}/6 守护引擎已激活，建议开启更多守护提升安全`

  let score = 100
  const recommendations: string[] = []

  if (wifiInfo.riskLevel === RiskLevel.DANGEROUS) {
    score -= 25
    recommendations.push('🔴 立即断开不安全的Wi-Fi，切换到移动数据或受保护的网络')
  } else if (wifiInfo.riskLevel === RiskLevel.SUSPICIOUS) {
    score -= 12
    recommendations.push('🟡 注意当前Wi-Fi安全性，避免输入敏感信息')
  }

  if (stats.dangerousCount > 0) {
    score -= Math.min(15, stats.dangerousCount * 5)
    recommendations.push(`🔴 发现 ${stats.dangerousCount} 个危险项，建议立即处理`)
  }
  if (stats.suspiciousCount > 2) {
    score -= Math.min(8, (stats.suspiciousCount - 2) * 3)
    recommendations.push('🟡 多个可疑项待处理，建议逐项排查')
  }

  if (!clipboardOn) {
    score -= 5
    recommendations.push('🟡 开启剪贴板守护，自动检测复制的链接')
  }
  if (!networkOn) {
    score -= 3
    recommendations.push('🟡 开启网络守护，实时监控网络变化')
  }
  if (activeMonitorCount < 3) {
    score -= 5
    recommendations.push('🟡 建议至少开启3个守护引擎以获得基本防护')
  }

  if (recommendations.length === 0) {
    recommendations.push('🟢 继续保持良好安全习惯')
    recommendations.push('🟢 定期做安全体检（建议每周一次）')
  }

  report.recommendations = recommendations
  report.overallScore = Math.max(0, Math.min(100, score))

  if (report.overallScore >= 80) {
    report.overallRiskLevel = RiskLevel.SAFE
    report.summary = `安全评分 ${report.overallScore}/100，整体状态良好。`
  } else if (report.overallScore >= 60) {
    report.overallRiskLevel = RiskLevel.SUSPICIOUS
    report.summary = `安全评分 ${report.overallScore}/100，存在安全隐患需要关注。`
  } else {
    report.overallRiskLevel = RiskLevel.DANGEROUS
    report.summary = `安全评分 ${report.overallScore}/100，发现较多风险，请尽快处理！`
  }

  hilog.info(DOMAIN, TAG, `Report generated: score=${report.overallScore}`)
  return report
}

export function formatReportAsText(report: SecurityReport): string {
  const date = new Date(report.generatedAt)
  const dateStr = `${date.getFullYear()}/${(date.getMonth() + 1).toString().padStart(2, '0')}/${date.getDate().toString().padStart(2, '0')} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`

  let text = `🛡️ 谛听·安全报告\n`
  text += `━━━━━━━━━━━━━━━━━━━━\n`
  text += `📅 ${dateStr}\n\n`

  text += `📊 综合评分：${report.overallScore}/100 `
  if (report.overallScore >= 80) { text += '🟢 良好' }
  else if (report.overallScore >= 60) { text += '🟡 需关注' }
  else { text += '🔴 有风险' }
  text += '\n\n'

  text += `📡 网络安全\n`
  text += `  Wi-Fi: ${report.networkSection.wifiSsid || '未连接'}\n`
  text += `  加密: ${report.networkSection.wifiSecurityType}\n`
  if (report.networkSection.wifiSignalQuality.length > 0) {
    text += `  信号: ${report.networkSection.wifiSignalQuality}\n`
  }
  text += `  状态: ${report.networkSection.isSecure ? '🟢 安全' : '🔴 有风险'}\n`
  text += '\n'

  text += `🔐 权限与隐私\n`
  text += `  权限风险: ${report.permissionSection.riskFound} 项\n`
  text += `  守护引擎: ${report.privacySection.activeMonitorCount}/6 已激活\n`
  text += `  📋 剪贴板: ${report.privacySection.clipboardMonitorOn ? '🟢' : '⚪'}  🌐 网络: ${report.privacySection.networkWatchOn ? '🟢' : '⚪'}  📱 应用: ${report.privacySection.appLifecycleOn ? '🟢' : '⚪'}\n`
  text += `  🔋 电池USB: ${report.privacySection.batteryUsbOn ? '🟢' : '⚪'}  📶 蓝牙: ${report.privacySection.bluetoothOn ? '🟢' : '⚪'}  📡 SIM: ${report.privacySection.simChangeOn ? '🟢' : '⚪'}\n`
  text += '\n'

  text += `📋 检测统计\n`
  text += `  总检测: ${report.historySection.totalChecks} 次\n`
  text += `  🟢 安全: ${report.historySection.safeCount} | 🟡 可疑: ${report.historySection.suspiciousCount} | 🔴 危险: ${report.historySection.dangerousCount}\n`
  if (report.historySection.recentThreats.length > 0) {
    text += `  近期威胁:\n`
    for (const t of report.historySection.recentThreats.slice(0, 5)) {
      text += `    ⚠️ ${t}\n`
    }
  }
  text += '\n'

  text += `💡 优先建议\n`
  for (let i = 0; i < report.recommendations.length; i++) {
    text += `  ${i + 1}. ${report.recommendations[i]}\n`
  }

  text += '\n━━━━━━━━━━━━━━━━━━━━\n'
  text += APP_SLOGAN

  return text
}
