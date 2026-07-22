import { wifiManager } from '@kit.ConnectivityKit'
import { connection } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RiskLevel } from '../model/ChatModel'

const DOMAIN = 0xF000
const TAG = 'DiTingWifi'

export class WifiSecurityInfo {
  ssid: string = ''
  bssid: string = ''
  securityType: string = ''
  secTypeValue: number = -1
  rssi: number = 0
  signalQuality: string = ''
  band: number = 0
  frequency: number = 0
  linkSpeed: number = 0
  isHidden: boolean = false
  riskLevel: RiskLevel = RiskLevel.SAFE
  riskDetails: string[] = []
  summary: string = ''
}

export function checkWifiSecurity(): WifiSecurityInfo {
  const info = new WifiSecurityInfo()

  try {
    if (!wifiManager.isWifiActive()) {
      info.riskLevel = RiskLevel.SAFE
      info.summary = 'Wi-Fi 未开启，当前不使用无线网络。'
      info.securityType = '未启用'
      return info
    }

    const linkedInfo = wifiManager.getLinkedInfoSync()
    const ssid = linkedInfo.ssid
    if (ssid.length > 2 && ssid.startsWith('"') && ssid.endsWith('"')) {
      info.ssid = ssid.substring(1, ssid.length - 1)
    } else {
      info.ssid = ssid
    }
    info.rssi = linkedInfo.rssi
    info.band = linkedInfo.band
    info.frequency = linkedInfo.frequency
    info.linkSpeed = linkedInfo.linkSpeed
    info.isHidden = linkedInfo.isHidden
    info.bssid = linkedInfo.bssid

    if (info.rssi > -50) {
      info.signalQuality = '优秀'
      info.riskDetails.push('信号强度优秀')
    } else if (info.rssi > -60) {
      info.signalQuality = '良好'
      info.riskDetails.push('信号强度良好')
    } else if (info.rssi > -70) {
      info.signalQuality = '一般'
      info.riskDetails.push('信号强度一般')
    } else {
      info.signalQuality = '较弱'
      info.riskDetails.push('信号较弱，可能影响连接稳定性')
    }

    let secType: wifiManager.WifiSecurityType = wifiManager.WifiSecurityType.WIFI_SEC_TYPE_INVALID
    try {
      const scanList: Array<wifiManager.WifiScanInfo> = wifiManager.getScanInfoList()
      const targetBssid = linkedInfo.bssid
      for (const scan of scanList) {
        if (scan.bssid === targetBssid || scan.ssid === ssid) {
          secType = scan.securityType
          break
        }
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Scan info unavailable: ${(err as Error).message}`)
    }

    info.secTypeValue = secType
    info.securityType = getSecurityTypeName(secType)

    if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_OPEN) {
      info.riskLevel = RiskLevel.DANGEROUS
      info.riskDetails.push('开放网络（无密码保护）')
      info.summary = `当前连接的 Wi-Fi "${info.ssid}" 是开放网络，任何人都可以连接，数据传输未加密，存在严重安全风险！`
    } else if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_OWE) {
      info.riskLevel = RiskLevel.SUSPICIOUS
      info.riskDetails.push('OWE增强开放网络，加密有限')
      info.summary = `当前 Wi-Fi "${info.ssid}" 使用 OWE 加密，虽比开放网络安全但仍有限，建议切换到受密码保护的网络。`
    } else if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_WEP) {
      info.riskLevel = RiskLevel.DANGEROUS
      info.riskDetails.push('WEP 加密已过时，极易被破解')
      info.summary = `当前 Wi-Fi "${info.ssid}" 使用过时的 WEP 加密，可在数分钟内被破解，建议更换为 WPA2/WPA3。`
    } else if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_PSK) {
      info.riskLevel = RiskLevel.SAFE
      info.summary = `当前 Wi-Fi "${info.ssid}" 使用 WPA/WPA2-PSK 加密，连接安全。`
    } else if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_SAE) {
      info.riskLevel = RiskLevel.SAFE
      info.summary = `当前 Wi-Fi "${info.ssid}" 使用 WPA3-SAE 加密，安全性最高！`
    } else if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_EAP) {
      info.riskLevel = RiskLevel.SAFE
      info.summary = `当前 Wi-Fi "${info.ssid}" 使用 WPA/WPA2-Enterprise 加密，企业级安全。`
    } else if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_EAP_SUITE_B) {
      info.riskLevel = RiskLevel.SAFE
      info.summary = `当前 Wi-Fi "${info.ssid}" 使用 WPA3-Enterprise Suite-B 加密，最高安全等级！`
    } else if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_WAPI_CERT ||
               secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_WAPI_PSK) {
      info.riskLevel = RiskLevel.SAFE
      info.summary = `当前 Wi-Fi "${info.ssid}" 使用 WAPI 加密，连接安全。`
    } else {
      info.riskLevel = RiskLevel.SUSPICIOUS
      info.summary = `当前 Wi-Fi "${info.ssid}" 的安全类型为 ${info.securityType}，无法确定安全性，建议谨慎使用。`
    }

    if (info.isHidden) {
      info.riskDetails.push('隐藏SSID网络')
      if (info.riskLevel === RiskLevel.SAFE) {
        info.riskLevel = RiskLevel.SUSPICIOUS
      }
      info.summary += ' 注意：该网络隐藏了SSID，需谨慎确认网络真实性。'
    }

    if (info.bssid.length > 0 && isLocallyAdministeredBssid(info.bssid)) {
      info.riskDetails.push('BSSID为随机地址，可能是移动热点')
      if (info.riskLevel === RiskLevel.SAFE) {
        info.riskLevel = RiskLevel.SUSPICIOUS
      }
      info.summary += ' 注意：该接入点使用随机MAC地址，可能是移动设备热点，请确认网络来源。'
    }

    try {
      const netHandle = connection.getDefaultNetSync()
      const netCap = connection.getNetCapabilitiesSync(netHandle)
      const networkCap = netCap.networkCap || []
      const isPortal = networkCap.indexOf(connection.NetCap.NET_CAPABILITY_PORTAL) >= 0
      if (isPortal) {
        info.riskDetails.push('需要Portal认证（公共网络）')
        if (info.riskLevel === RiskLevel.SAFE) {
          info.riskLevel = RiskLevel.SUSPICIOUS
          info.summary = `Wi-Fi "${info.ssid}" 加密安全，但需要Portal认证，可能是公共网络，注意不要在认证页面输入敏感信息。`
        }
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Net capability check skipped: ${(err as Error).message}`)
    }
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `checkWifiSecurity failed: ${e.message}`)
    info.riskLevel = RiskLevel.SUSPICIOUS
    info.summary = '无法获取Wi-Fi信息，可能未连接Wi-Fi，安全性不确定。'
    info.securityType = '未知'
  }

  return info
}

function getSecurityTypeName(secType: wifiManager.WifiSecurityType): string {
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_OPEN) { return '开放(无加密)' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_WEP) { return 'WEP(已过时)' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_PSK) { return 'WPA/WPA2-PSK' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_SAE) { return 'WPA3-SAE' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_EAP) { return 'WPA/WPA2-Enterprise' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_EAP_SUITE_B) { return 'WPA3-Enterprise Suite-B' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_OWE) { return 'OWE(增强开放)' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_WAPI_CERT) { return 'WAPI-CERT' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_WAPI_PSK) { return 'WAPI-PSK' }
  if (secType === wifiManager.WifiSecurityType.WIFI_SEC_TYPE_INVALID) { return '未知/未扫描到' }
  return '未知'
}

function isLocallyAdministeredBssid(bssid: string): boolean {
  const parts = bssid.split(':')
  if (parts.length !== 6) {
    return false
  }
  const firstByte = parseInt(parts[0], 16)
  return (firstByte & 0x02) === 0x02
}
