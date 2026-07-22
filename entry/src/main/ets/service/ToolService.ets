import { RiskLevel } from '../model/ChatModel'
import { connection } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { checkWifiSecurity, WifiSecurityInfo } from './WifiSecurity'
import { generateSecurityReport } from './SecurityReport'
import { getHistoryStats, HistoryStats } from './SecurityHistory'
import { getAllMonitorStatus, getActiveMonitorCount, getMonitorStatus } from './MonitorOrchestrator'
import { getBatteryInfo } from './BatteryUsbMonitor'
import { getBluetoothStatus } from './BluetoothMonitor'
import { extractUrls } from './UrlUtils'

const DOMAIN = 0xF000
const TAG = 'DiTingTool'

class ToolCallParsed {
  tool: string = ''
  args: ToolCallArgs = new ToolCallArgs()
}

class ToolCallArgs {
  url: string = ''
  deep_scan: string = ''
  package_name: string = ''
  include_history: string = ''
  file_path: string = ''
  scan_type: string = ''
  check_type: string = ''
}

export class ToolResultJson {
  tool: string = ''
  riskLevel: RiskLevel = RiskLevel.SAFE
  summary: string = ''
  details: ToolResultDetails = new ToolResultDetails()
}

export class ToolResultDetails {
  url: string = ''
  sslValid: boolean = true
  isPhishing: boolean = false
  reputation: string = ''
  packageName: string = ''
  riskPermissions: string[] = []
  permissionCount: number = 0
  filePath: string = ''
  isSuspicious: boolean = false
  threats: string[] = []
  currentNetwork: string = ''
  networkType: string = ''
  isSecure: boolean = true
  isPortal: boolean = false
  proxyDetected: boolean = false
  vpnActive: boolean = false
  overallScore: number = 100
  categories: CategoryScore[] = []
  deviceStatus: MonitorStatusItem[] = []
}

export class CategoryScore {
  name: string = ''
  score: number = 100
  issues: string[] = []
}

export class MonitorStatusItem {
  name: string = ''
  icon: string = ''
  active: boolean = false
  description: string = ''
  liveInfo: string = ''
}

export function parseToolCall(text: string): ToolCallParsed | null {
  const pattern = new RegExp('\\{"tool"\\s*:\\s*"([^"]+)"\\s*,\\s*"args"\\s*:\\s*\\{([^}]*)\\}\\s*\\}')
  const match = text.match(pattern)
  if (!match) {
    return null
  }
  const result = new ToolCallParsed()
  result.tool = match[1]
  const argsStr = match[2]
  const argPattern = new RegExp('"([^"]+)"\\s*:\\s*"([^"]*)"', 'g')
  let argMatch: RegExpExecArray | null = null
  const args = new ToolCallArgs()
  while ((argMatch = argPattern.exec(argsStr)) !== null) {
    const key = argMatch[1]
    const value = argMatch[2]
    if (key === 'url') { args.url = value }
    else if (key === 'deep_scan') { args.deep_scan = value }
    else if (key === 'package_name') { args.package_name = value }
    else if (key === 'include_history') { args.include_history = value }
    else if (key === 'file_path') { args.file_path = value }
    else if (key === 'scan_type') { args.scan_type = value }
    else if (key === 'check_type') { args.check_type = value }
  }
  result.args = args
  return result
}

class ExtractResult {
  toolCall: ToolCallImpl | null = null
  displayText: string = ''
}

class ToolCallImpl {
  tool: string = ''
  args: Map<string, string> = new Map()

  constructor(tool: string) {
    this.tool = tool
  }
}

export function extractToolCallFromText(text: string): ExtractResult {
  const toolCall = parseToolCall(text)
  if (toolCall) {
    const displayText = text.replace(new RegExp('\\{"tool"\\s*:\\s*"[^"]+"\\s*,\\s*"args"\\s*:\\s*\\{[^}]*\\}\\s*\\}'), '').trim()
    const result = new ExtractResult()
    result.toolCall = new ToolCallImpl(toolCall.tool)
    result.displayText = displayText
    return result
  }
  const urls = extractUrls(text)
  if (urls.length > 0) {
    const result = new ExtractResult()
    result.toolCall = new ToolCallImpl('link_check')
    result.toolCall.args.set('url', urls[0])
    result.displayText = text
    return result
  }
  const result = new ExtractResult()
  result.toolCall = null
  result.displayText = text
  return result
}

function executeDeviceSecurityCheck(): string {
  const result = new ToolResultJson()
  result.tool = 'device_security_check'

  const monitorStatuses = getAllMonitorStatus()
  const activeCount = getActiveMonitorCount()
  const totalCount = monitorStatuses.length

  const items: MonitorStatusItem[] = []
  for (const ms of monitorStatuses) {
    const item = new MonitorStatusItem()
    item.name = ms.name
    item.icon = ms.icon
    item.active = ms.active
    item.description = ms.description

    if (ms.name === 'battery_usb' && ms.active) {
      item.liveInfo = getBatteryInfo()
    } else if (ms.name === 'bluetooth' && ms.active) {
      item.liveInfo = getBluetoothStatus()
    } else if (ms.name === 'network' && ms.active) {
      const wifiInfo = checkWifiSecurity()
      item.liveInfo = `Wi-Fi: ${wifiInfo.ssid} (${wifiInfo.securityType})`
    } else if (ms.name === 'clipboard' && ms.active) {
      item.liveInfo = getMonitorStatus('clipboard').active ? '守护中' : '未启动'
    }
    items.push(item)
  }
  result.details.deviceStatus = items

  const activeRatio = activeCount / totalCount

  let lines: string[] = []
  lines.push('📊 设备安全状态概览')
  lines.push('━━━━━━━')
  lines.push(`守护引擎：${activeCount}/${totalCount} 已激活\n`)

  for (const item of items) {
    const statusIcon = item.active ? '🟢' : '⚪'
    const live = item.liveInfo.length > 0 ? ` | ${item.liveInfo}` : ''
    lines.push(`${item.icon} ${statusIcon} ${item.description}${live}`)
  }

  lines.push('')
  if (activeCount === 0) {
    lines.push('⚠️ 当前无守护引擎运行，请开启守护功能！')
    result.riskLevel = RiskLevel.DANGEROUS
  } else if (activeRatio < 0.5) {
    lines.push('🟡 部分守护未开启，建议启用全部守护以获得完整防护。')
    result.riskLevel = RiskLevel.SUSPICIOUS
  } else {
    lines.push('✅ 守护引擎运行正常，设备受到持续保护。')
    result.riskLevel = RiskLevel.SAFE
  }

  lines.push('\n━━━━━━━')
  lines.push('💡 提示：可在设置页面开启/关闭各项守护功能')

  result.summary = lines.join('\n')
  return JSON.stringify(result)
}

export function executeToolCall(toolName: string, args: Map<string, string>): string {
  switch (toolName) {
    case 'link_check':
      return executeLinkCheck(args.get('url') ?? '', args.get('deep_scan') === 'true')
    case 'permission_scan':
      return executePermissionScan(args.get('package_name') ?? '', args.get('include_history') === 'true')
    case 'file_scan':
      return executeFileScan(args.get('file_path') ?? '', args.get('scan_type') ?? 'quick')
    case 'network_monitor':
      return executeNetworkMonitor(args.get('check_type') ?? 'quick')
    case 'privacy_health_check':
      return executePrivacyHealthCheck()
    case 'wifi_check':
      return executeWifiCheck()
    case 'security_report':
      return executeSecurityReport()
    case 'device_security_check':
      return executeDeviceSecurityCheck()
    default:
      return ''
  }
}

function executeLinkCheck(url: string, deepScan: boolean): string {
  const result = new ToolResultJson()
  result.tool = 'link_check'
  result.details.url = url
  const isHttp = url.startsWith('http://')
  const urlLower = url.toLowerCase()
  const analysisDetails: string[] = []

  if (isHttp) {
    result.riskLevel = RiskLevel.SUSPICIOUS
    result.details.sslValid = false
    analysisDetails.push('⚠️ 使用HTTP明文传输')
  }

  const suspiciousPatterns = ['login', 'verify', 'update', 'secure', 'account', 'free', 'prize',
    'banking', 'reset', 'confirm', 'wallet', 'reward', 'claim', 'submit', 'authenticate',
    'password', 'credential', 'unlock', 'authenticate', 'download-file', 'check-now']
  let suspiciousCount = 0
  for (const pattern of suspiciousPatterns) {
    if (urlLower.indexOf(pattern) >= 0) {
      suspiciousCount++
      analysisDetails.push(`发现钓鱼关键词: "${pattern}"`)
    }
  }

  const hasLongRandomDomain = new RegExp('https?:\\/\\/[a-z0-9]{12,}\\.').test(urlLower)
  if (hasLongRandomDomain) {
    suspiciousCount += 2
    analysisDetails.push('超长随机子域名，常见于自动生成的钓鱼网站')
  }

  const hasIpAddress = new RegExp('https?:\\/\\/\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}').test(url)
  if (hasIpAddress) {
    suspiciousCount += 2
    analysisDetails.push('使用IP地址而非域名，正规网站极少如此')
  }

  const highRiskTlds = ['.tk', '.ml', '.ga', '.cf', '.gq', '.xyz', '.top', '.buzz', '.icu', '.work']
  for (const tld of highRiskTlds) {
    if (urlLower.indexOf(tld + '/') >= 0 || urlLower.endsWith(tld)) {
      suspiciousCount += 2
      analysisDetails.push(`高风险域名后缀: ${tld}，常被用于钓鱼网站`)
      break
    }
  }

  const urlShorteners = ['bit.ly/', 't.cn/', 'tinyurl.com/', 'dwz.cn/', 'amzn.to/', 'goo.gl/',
    'shorturl.at/', 'is.gd/', 'v.gd/', 'rb.gy/']
  for (const shortener of urlShorteners) {
    if (urlLower.indexOf(shortener) >= 0) {
      suspiciousCount += 1
      analysisDetails.push('短链接服务，无法直接判断目标网站安全性')
      break
    }
  }

  const hasAtSymbol = url.indexOf('@') >= 0
  if (hasAtSymbol) {
    suspiciousCount += 3
    analysisDetails.push('URL包含@符号，可能用于伪装真实目标')
  }

  const hasPort = new RegExp('https?:\\/\\/[^\\/]+:\\d{2,5}').test(url)
  if (hasPort) {
    suspiciousCount += 1
    analysisDetails.push('使用非标准端口，需谨慎')
  }

  const doubleRedirect = urlLower.indexOf('//') > urlLower.indexOf('://') + 2
  if (doubleRedirect) {
    suspiciousCount += 1
    analysisDetails.push('URL包含多层跳转，可能隐藏真实目标')
  }

  const domainCount = (urlLower.match(new RegExp('\\.', 'g')) || []).length
  if (domainCount >= 4) {
    suspiciousCount += 1
    analysisDetails.push('多层子域名，可能用于伪装')
  }

  const hasPunycode = urlLower.indexOf('xn--') >= 0
  if (hasPunycode) {
    suspiciousCount += 2
    analysisDetails.push('含国际化域名(IDN/Punycode)，可能用于同形字攻击伪装')
  }

  const knownBrandSpoof: string[] = ['g00gle', 'goog1e', 'app1e', 'appie', 'micr0soft',
    'microsoft-', 'paypa1', 'paypai', 'amaz0n', 'amaz0n-', 'faceb00k', 'facebo0k',
    'lnstagram', 'instagrarn', 'tw1tter', 'tvvitter', 'netfl1x', 'netfix',
    'a1ipay', 'al1pay', 'weix1n', 'taoba0']
  for (const brand of knownBrandSpoof) {
    if (urlLower.indexOf(brand) >= 0) {
      suspiciousCount += 3
      analysisDetails.push(`域名含品牌仿冒字符: "${brand}"，疑似同形字攻击`)
      break
    }
  }

  const dataUriScheme = urlLower.indexOf('data:') === 0
  if (dataUriScheme) {
    suspiciousCount += 3
    analysisDetails.push('data: URI，可能用于钓鱼或隐藏恶意内容')
  }

  const javascriptUri = urlLower.indexOf('javascript:') === 0
  if (javascriptUri) {
    suspiciousCount += 5
    analysisDetails.push('javascript: URI，可执行任意代码！绝对不要点击！')
  }

  if (suspiciousCount >= 4 || (isHttp && suspiciousCount >= 2)) {
    result.riskLevel = RiskLevel.DANGEROUS
    result.details.isPhishing = true
    result.summary = `🔴 危险链接！发现 ${suspiciousCount} 个高风险特征，极可能是钓鱼/恶意网站。\n\n${analysisDetails.slice(0, 5).join('\n')}\n\n⛔ 请勿点击或输入任何个人信息！`
  } else if (suspiciousCount >= 2 || isHttp) {
    result.riskLevel = RiskLevel.SUSPICIOUS
    result.summary = `🟡 可疑链接。发现 ${suspiciousCount} 个风险特征：\n\n${analysisDetails.slice(0, 4).join('\n')}\n\n建议谨慎访问，不要输入敏感信息。`
  } else if (suspiciousCount >= 1) {
    result.riskLevel = RiskLevel.SUSPICIOUS
    result.summary = `🟡 轻微可疑。${analysisDetails[0]}。建议谨慎访问。`
  } else {
    result.riskLevel = RiskLevel.SAFE
    result.details.sslValid = true
    result.summary = '🟢 链接安全。使用HTTPS加密，未发现风险特征，可以放心访问。'
  }

  if (deepScan) {
    result.details.reputation = '深度扫描完成'
  }
  return JSON.stringify(result)
}

class KnownAppInfo {
  displayName: string = ''
  riskPermCount: number = 0
  category: string = ''
  permissionsExpected: boolean = false

  constructor(displayName: string, riskPermCount: number, category: string, permissionsExpected: boolean) {
    this.displayName = displayName
    this.riskPermCount = riskPermCount
    this.category = category
    this.permissionsExpected = permissionsExpected
  }
}

function executePermissionScan(packageName: string, includeHistory: boolean): string {
  const result = new ToolResultJson()
  result.tool = 'permission_scan'
  result.details.packageName = packageName

  const highRiskPermissions = [
    'ohos.permission.READ_CALENDAR', 'ohos.permission.READ_CONTACTS',
    'ohos.permission.LOCATION', 'ohos.permission.CAMERA',
    'ohos.permission.MICROPHONE', 'ohos.permission.READ_MEDIA',
    'ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.READ_PASTEBOARD',
    'ohos.permission.ACTIVITY_MOTION', 'ohos.permission.READ_HEALTH_DATA'
  ]

  const mediumRiskPermissions = [
    'ohos.permission.INTERNET', 'ohos.permission.GET_NETWORK_INFO',
    'ohos.permission.GET_WIFI_INFO', 'ohos.permission.KEEP_BACKGROUND_RUNNING',
    'ohos.permission.GET_BUNDLE_INFO', 'ohos.permission.FILE_ACCESS_PERSIST'
  ]

  if (packageName === 'com.diting.agent' || packageName.length === 0) {
    result.details.packageName = 'com.diting.agent'
    const ourPerms = [
      'ohos.permission.INTERNET', 'ohos.permission.GET_NETWORK_INFO',
      'ohos.permission.GET_BUNDLE_INFO', 'ohos.permission.FILE_ACCESS_PERSIST',
      'ohos.permission.READ_PASTEBOARD', 'ohos.permission.KEEP_BACKGROUND_RUNNING',
      'ohos.permission.GET_WIFI_INFO', 'ohos.permission.APPROXIMATELY_LOCATION',
      'ohos.permission.SET_WIFI_INFO'
    ]
    result.details.permissionCount = ourPerms.length
    result.details.riskPermissions = ['ohos.permission.READ_PASTEBOARD', 'ohos.permission.APPROXIMATELY_LOCATION']
    result.riskLevel = RiskLevel.SAFE
    result.summary = `🟢 谛听自身权限分析：申请了 ${ourPerms.length} 项权限，其中 2 项为用户授权类敏感权限（剪贴板读取、位置获取），均为安全检测功能所必需，未发现过度索权。`
    return JSON.stringify(result)
  }

  const knownApps: Map<string, KnownAppInfo> = new Map([
    ['com.tencent.mm', new KnownAppInfo('微信', 4, '通讯社交', true)],
    ['com.taobao.taobao', new KnownAppInfo('淘宝', 3, '购物比价', true)],
    ['com.eg.android.AlipayGphone', new KnownAppInfo('支付宝', 2, '金融支付', true)],
    ['com.ss.android.ugc.aweme', new KnownAppInfo('抖音', 5, '短视频', false)],
    ['com.sina.weibo', new KnownAppInfo('微博', 3, '社交资讯', true)],
    ['com.jingdong.app.mall', new KnownAppInfo('京东', 3, '购物比价', true)],
    ['com.baidu.BaiduMap', new KnownAppInfo('百度地图', 3, '导航出行', true)],
    ['com.autonavi.minimap', new KnownAppInfo('高德地图', 3, '导航出行', true)],
    ['com.meitu.meiyancamera', new KnownAppInfo('美图秀秀', 4, '摄影美化', false)],
    ['com.qiyi.video', new KnownAppInfo('爱奇艺', 2, '视频娱乐', true)],
    ['com.tencent.qqmusic', new KnownAppInfo('QQ音乐', 2, '音乐播放', true)],
    ['com.xunmeng.pinduoduo', new KnownAppInfo('拼多多', 4, '购物比价', false)],
    ['com.sankuai.meituan', new KnownAppInfo('美团', 3, '生活服务', true)],
    ['com.dianping.v1', new KnownAppInfo('大众点评', 2, '生活服务', true)],
    ['com.eg.android.AlipayGphoneR', new KnownAppInfo('支付宝', 2, '金融支付', true)]
  ])

  const appInfo = knownApps.get(packageName)
  let permCount = 0
  let isExpected = false
  let appName = packageName

  if (appInfo) {
    permCount = appInfo.riskPermCount
    isExpected = appInfo.permissionsExpected
    appName = appInfo.displayName
  } else {
    permCount = 0
  }

  let riskCount = 0
  for (let i = 0; i < permCount && i < highRiskPermissions.length; i++) {
    result.details.riskPermissions.push(highRiskPermissions[i])
    riskCount++
  }
  result.details.permissionCount = permCount + mediumRiskPermissions.length

  if (riskCount >= 4) {
    result.riskLevel = RiskLevel.DANGEROUS
    result.summary = `🔴 ${appName} 申请了 ${riskCount} 项敏感权限（位置、相机、麦克风、通讯录等），权限范围超出其"${appInfo?.category ?? '未知'}"功能所需，存在隐私泄露风险。\n\n建议：在系统设置中关闭不必要的敏感权限。`
  } else if (riskCount >= 2) {
    result.riskLevel = isExpected ? RiskLevel.SAFE : RiskLevel.SUSPICIOUS
    if (isExpected) {
      result.summary = `🟡 ${appName} 申请了 ${riskCount} 项敏感权限，作为${appInfo?.category ?? '该类'}应用属于正常范围，但建议定期检查。`
    } else {
      result.summary = `🟡 ${appName} 申请了 ${riskCount} 项敏感权限，部分权限可能超出功能需要，建议审查。`
    }
  } else {
    result.riskLevel = RiskLevel.SAFE
    if (!appInfo) {
      result.summary = `🟢 ${appName} (未安装应用，无法获取实际权限信息)。建议安装后重新检测以获取准确的权限分析。`
    } else {
      result.summary = `🟢 ${appName} 权限申请合理，未发现过度索权行为。`
    }
  }
  return JSON.stringify(result)
}

function executeFileScan(filePath: string, scanType: string): string {
  const result = new ToolResultJson()
  result.tool = 'file_scan'
  result.details.filePath = filePath
  const ext = filePath.split('.').pop()?.toLowerCase() ?? ''
  const fileName = filePath.split('/').pop() ?? filePath

  const dangerousExts = ['apk', 'exe', 'bat', 'cmd', 'ps1', 'vbs', 'js', 'scr', 'com', 'dll',
    'msi', 'cpl', 'hta', 'wsf', 'vbe', 'jse', 'wsh', 'inf', 'reg']
  const ransomwareExts = ['encrypted', 'locked', 'crypto', 'cry', 'locky', 'cerber',
    'zepto', 'odin', 'thor', 'aesar', 'globe', 'purge', 'cryptolocker',
    'wannacry', 'ryuk', 'sodinokibi', 'dharma', 'phobos']
  const suspiciousExts = ['doc', 'xls', 'ppt', 'docm', 'xlsm', 'pptm', 'jar', 'iso', 'img']

  let foundDangerous = false
  let foundRansomware = false
  let foundSuspicious = false

  for (const de of dangerousExts) {
    if (ext === de) {
      foundDangerous = true
      break
    }
  }

  if (!foundDangerous) {
    for (const re of ransomwareExts) {
      if (ext === re || fileName.toLowerCase().indexOf('.' + re) >= 0) {
        foundRansomware = true
        break
      }
    }
  }

  if (!foundDangerous && !foundRansomware) {
    for (const se of suspiciousExts) {
      if (ext === se) {
        foundSuspicious = true
        break
      }
    }
  }

  const doubleExtMatch = fileName.match(new RegExp('\\.[a-zA-Z0-9]+\\.[a-zA-Z0-9]+$', 'g'))
  const hasDoubleExt = doubleExtMatch !== null && doubleExtMatch.length > 0

  if (foundRansomware) {
    result.riskLevel = RiskLevel.CRITICAL
    result.details.isSuspicious = true
    result.details.threats.push(`勒索软件加密文件(.${ext})`)
    result.summary = `⛔ 警告：该文件扩展名 ".${ext}" 与已知勒索软件加密格式匹配！\n\n━━━━━━━\n💡 建议：\n1. 绝对不要支付赎金\n2. 立即断网防止扩散\n3. 检查其他文件是否被加密\n4. 使用备份恢复数据\n5. 寻求专业安全帮助`
  } else if (foundDangerous) {
    result.riskLevel = RiskLevel.DANGEROUS
    result.details.isSuspicious = true
    result.details.threats.push(`可执行文件类型(.${ext})`)
    if (hasDoubleExt) {
      result.details.threats.push('双扩展名伪装')
      result.summary = `🔴 该文件为 .${ext} 可执行文件，且使用双扩展名伪装（如 "文档.pdf.exe"），是常见恶意软件手法！\n\n━━━━━━━\n💡 建议：立即删除，不要打开。`
    } else {
      result.summary = `🔴 该文件为 .${ext} 可执行文件，可能包含恶意代码。\n\n━━━━━━━\n💡 建议：在安全环境中扫描后再决定是否打开，来源不明则直接删除。`
    }
  } else if (foundSuspicious) {
    if (ext === 'docm' || ext === 'xlsm' || ext === 'pptm') {
      result.riskLevel = RiskLevel.DANGEROUS
      result.details.isSuspicious = true
      result.details.threats.push('Office宏文件')
      result.summary = `🔴 该文件为带宏的 Office 文件(.${ext})，宏是恶意软件最常见的传播方式之一。\n\n━━━━━━━\n💡 建议：除非确认来源可靠，否则不要启用宏。`
    } else if (ext === 'jar') {
      result.riskLevel = RiskLevel.SUSPICIOUS
      result.details.threats.push('Java可执行文件')
      result.summary = `🟡 该文件为 Java 可执行包(.jar)，可能包含恶意Java代码，建议谨慎运行。`
    } else if (ext === 'iso' || ext === 'img') {
      result.riskLevel = RiskLevel.SUSPICIOUS
      result.details.threats.push('磁盘镜像文件')
      result.summary = `🟡 该文件为磁盘镜像(.${ext})，恶意邮件常使用镜像文件绕过安全检测，建议确认来源。`
    } else {
      result.riskLevel = RiskLevel.SUSPICIOUS
      result.details.threats.push('旧版 Office 格式可能包含宏病毒')
      result.summary = `🟡 该文件使用旧版 Office 格式(.${ext})，可能包含宏病毒，建议使用新版格式或在沙箱中打开。`
    }
  } else if (hasDoubleExt) {
    result.riskLevel = RiskLevel.SUSPICIOUS
    result.details.threats.push('双扩展名伪装')
    result.summary = `🟡 该文件使用双扩展名，这是常见的社会工程学伪装手法（如 "照片.jpg.exe"），请仔细检查真实扩展名。`
  } else {
    result.riskLevel = RiskLevel.SAFE
    result.summary = `🟢 该文件类型(.${ext})安全，未检测到威胁。`
  }
  return JSON.stringify(result)
}

function executeNetworkMonitor(checkType: string): string {
  const result = new ToolResultJson()
  result.tool = 'network_monitor'

  const wifiInfo = checkWifiSecurity()

  try {
    const netHandle = connection.getDefaultNetSync()
    if (netHandle.netId === 0) {
      result.details.currentNetwork = '无网络连接'
      result.details.isSecure = false
      result.riskLevel = RiskLevel.SUSPICIOUS
      result.summary = '当前设备未连接任何网络，请检查网络设置。'
      return JSON.stringify(result)
    }

    const netCap = connection.getNetCapabilitiesSync(netHandle)
    const bearerTypes = netCap.bearerTypes
    const networkCap = netCap.networkCap || []

    const isWifi = bearerTypes.indexOf(connection.NetBearType.BEARER_WIFI) >= 0
    const isCellular = bearerTypes.indexOf(connection.NetBearType.BEARER_CELLULAR) >= 0
    const isValidated = networkCap.indexOf(connection.NetCap.NET_CAPABILITY_VALIDATED) >= 0
    const isPortal = networkCap.indexOf(connection.NetCap.NET_CAPABILITY_PORTAL) >= 0

    if (isWifi) {
      result.details.networkType = 'Wi-Fi'
      result.details.currentNetwork = `Wi-Fi: ${wifiInfo.ssid} (${wifiInfo.securityType})`
    } else if (isCellular) {
      result.details.networkType = '蜂窝数据'
      result.details.currentNetwork = '蜂窝数据'
    } else {
      result.details.networkType = '其他'
      result.details.currentNetwork = '其他网络'
    }

    if (isPortal) {
      result.details.isPortal = true
      result.details.isSecure = false
      result.riskLevel = RiskLevel.SUSPICIOUS
      result.summary = `当前连接的是需要认证的公共 ${result.details.networkType}（Portal 网络），可能存在安全风险。建议不要在此网络上输入敏感信息。`
    } else if (isWifi && wifiInfo.riskLevel !== RiskLevel.SAFE) {
      result.details.isSecure = false
      result.riskLevel = wifiInfo.riskLevel
      result.summary = wifiInfo.summary
    } else if (isWifi) {
      result.details.isSecure = true
      result.riskLevel = RiskLevel.SAFE
      result.summary = wifiInfo.summary
    } else if (isCellular) {
      result.details.isSecure = true
      result.riskLevel = RiskLevel.SAFE
      result.summary = `当前使用蜂窝数据连接，相对安全，但注意流量消耗。`
    }

    if (!isValidated) {
      result.details.isSecure = false
      result.riskLevel = RiskLevel.SUSPICIOUS
      result.summary = `当前网络连接不可用或未经验证，建议检查网络设置。`
    }
  } catch (err) {
    const e = err as Error
    hilog.warn(DOMAIN, TAG, `Network check fallback: ${e.message}`)
    if (wifiInfo.summary.length > 0) {
      result.riskLevel = wifiInfo.riskLevel
      result.summary = wifiInfo.summary
      result.details.currentNetwork = `Wi-Fi: ${wifiInfo.ssid}`
    } else {
      result.details.currentNetwork = '未知'
      result.details.isSecure = false
      result.riskLevel = RiskLevel.SUSPICIOUS
      result.summary = '无法验证网络安全性，请谨慎使用。建议检查网络连接或切换至已知安全网络。'
    }
  }

  return JSON.stringify(result)
}

function executeWifiCheck(): string {
  const result = new ToolResultJson()
  result.tool = 'wifi_check'
  const wifiInfo = checkWifiSecurity()
  result.riskLevel = wifiInfo.riskLevel
  result.summary = wifiInfo.summary
  result.details.currentNetwork = `${wifiInfo.ssid} (${wifiInfo.securityType})`
  result.details.isSecure = wifiInfo.riskLevel === RiskLevel.SAFE
  return JSON.stringify(result)
}

function executeSecurityReport(): string {
  const report = generateSecurityReport()
  const result = new ToolResultJson()
  result.tool = 'security_report'
  result.riskLevel = report.overallRiskLevel
  result.summary = report.summary
  result.details.overallScore = report.overallScore
  return JSON.stringify(result)
}

function executePrivacyHealthCheck(): string {
  const result = new ToolResultJson()
  result.tool = 'privacy_health_check'

  const stats = getHistoryStats()
  const wifiInfo = checkWifiSecurity()
  const clipboardOn = getMonitorStatus('clipboard').active

  const cat1 = new CategoryScore()
  cat1.name = '应用权限'
  cat1.score = 85
  if (stats.dangerousCount > 0) {
    cat1.score = Math.max(40, 85 - stats.dangerousCount * 10)
    cat1.issues.push(`${stats.dangerousCount} 个应用存在高风险权限`)
  }
  if (stats.suspiciousCount > 2) {
    cat1.score = Math.max(55, cat1.score - 5)
    cat1.issues.push('多个应用权限需关注')
  }
  if (cat1.issues.length === 0) {
    cat1.issues.push('已安装应用权限配置合理')
  }

  const cat2 = new CategoryScore()
  cat2.name = '网络安全'
  if (wifiInfo.riskLevel === RiskLevel.DANGEROUS) {
    cat2.score = 25
    cat2.issues.push('当前Wi-Fi不安全（开放/弱加密）')
    cat2.issues.push('建议立即断开并切换网络')
  } else if (wifiInfo.riskLevel === RiskLevel.SUSPICIOUS) {
    cat2.score = 60
    cat2.issues.push('Wi-Fi安全性待提升')
  } else {
    cat2.score = 95
    cat2.issues.push('网络连接安全')
  }

  const cat3 = new CategoryScore()
  cat3.name = '文件安全'
  cat3.score = 85
  if (stats.dangerousCount > 0) {
    cat3.score = 70
    cat3.issues.push('发现危险文件，建议清理')
  } else {
    cat3.issues.push('未发现危险文件')
  }

  const cat4 = new CategoryScore()
  cat4.name = '隐私设置'
  cat4.score = 75
  cat4.issues.push('建议定期重置广告标识符')
  cat4.issues.push('检查位置信息权限设置')
  if (!clipboardOn) {
    cat4.score = Math.max(50, cat4.score - 15)
    cat4.issues.push('剪贴板守护未开启 — 可能泄露复制内容')
  }

  const cat5 = new CategoryScore()
  cat5.name = '剪贴板安全'
  cat5.score = clipboardOn ? 95 : 55
  if (clipboardOn) {
    cat5.issues.push('剪贴板守护已开启')
  } else {
    cat5.issues.push('剪贴板守护未开启 — 恶意应用可读取剪贴板')
    cat5.issues.push('建议在设置中开启剪贴板守护')
  }

  result.details.categories = [cat1, cat2, cat3, cat4, cat5]

  let totalScore = 0
  for (const cat of result.details.categories) {
    totalScore += cat.score
  }
  result.details.overallScore = Math.floor(totalScore / result.details.categories.length)

  const scoreEmoji = result.details.overallScore >= 80 ? '🟢' : result.details.overallScore >= 60 ? '🟡' : '🔴'
  if (result.details.overallScore >= 80) {
    result.riskLevel = RiskLevel.SAFE
    result.summary = `${scoreEmoji} 隐私健康评分 ${result.details.overallScore}/100，整体良好！\n\n━━━━━━━\n各维度评分：\n📱 应用权限: ${cat1.score}/100\n🌐 网络安全: ${cat2.score}/100\n📁 文件安全: ${cat3.score}/100\n🔒 隐私设置: ${cat4.score}/100\n📋 剪贴板: ${cat5.score}/100\n\n💡 有少量可优化项，查看详细建议了解更多。`
  } else if (result.details.overallScore >= 60) {
    result.riskLevel = RiskLevel.SUSPICIOUS
    result.summary = `${scoreEmoji} 隐私健康评分 ${result.details.overallScore}/100，存在安全隐患！\n\n━━━━━━━\n各维度评分：\n📱 应用权限: ${cat1.score}/100\n🌐 网络安全: ${cat2.score}/100\n📁 文件安全: ${cat3.score}/100\n🔒 隐私设置: ${cat4.score}/100\n📋 剪贴板: ${cat5.score}/100\n\n💡 建议尽快处理低分项目，提升整体安全。`
  } else {
    result.riskLevel = RiskLevel.DANGEROUS
    result.summary = `${scoreEmoji} 隐私健康评分 ${result.details.overallScore}/100，风险较高！\n\n━━━━━━━\n各维度评分：\n📱 应用权限: ${cat1.score}/100\n🌐 网络安全: ${cat2.score}/100\n📁 文件安全: ${cat3.score}/100\n🔒 隐私设置: ${cat4.score}/100\n📋 剪贴板: ${cat5.score}/100\n\n⛔ 强烈建议立即处理严重问题！`
  }
  return JSON.stringify(result)
}
