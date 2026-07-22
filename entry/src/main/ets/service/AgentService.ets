import { ChatMessage, MessageRole, RiskLevel, toRiskLevel } from '../model/ChatModel'
import { executeToolCall, ToolResultDetails, CategoryScore, MonitorStatusItem } from './ToolService'
import { extractUrls } from './UrlUtils'
import { addSecurityRecord } from './SecurityHistory'
import { generateSecurityReport, formatReportAsText, SecurityReport } from './SecurityReport'

class ToolResultData {
  tool: string = ''
  riskLevel: string = ''
  summary: string = ''
  details: ToolResultDetails = new ToolResultDetails()
}

export function processUserInput(userInput: string, history: ChatMessage[]): ChatMessage[] {
  const newMessages: ChatMessage[] = []
  const nextId = history.length > 0 ? history[history.length - 1].id + 1 : 1

  const userMsg = new ChatMessage(nextId, MessageRole.USER, userInput)
  newMessages.push(userMsg)

  const lowerInput = userInput.toLowerCase()
  let agentContent = ''
  let riskLevel = RiskLevel.SAFE
  let toolName = ''

  if (isLinkQuery(lowerInput, userInput)) {
    toolName = 'link_check'
    const urls = extractUrls(userInput)
    const url = urls.length > 0 ? urls[0] : ''
    if (url) {
      const args: Map<string, string> = new Map()
      args.set('url', url)
      const resultJson = executeToolCall('link_check', args)
      const result = parseToolResult(resultJson)
      riskLevel = toRiskLevel(result.riskLevel)
      agentContent = formatLinkCheckResult(result)
    } else {
      agentContent = '请提供需要检测的完整链接，我会帮你分析其安全性。'
    }
  } else if (isPermissionQuery(lowerInput)) {
    toolName = 'permission_scan'
    const packageName = extractPackageName(userInput)
    if (packageName) {
      const args: Map<string, string> = new Map()
      args.set('package_name', packageName)
      const resultJson = executeToolCall('permission_scan', args)
      const result = parseToolResult(resultJson)
      riskLevel = toRiskLevel(result.riskLevel)
      agentContent = formatPermissionScanResult(result)
    } else {
      agentContent = '请告诉我你想检查哪个应用的权限？比如"检查微信的权限"或提供应用包名。'
    }
  } else if (isFileQuery(lowerInput)) {
    toolName = 'file_scan'
    const filePath = extractFilePath(userInput)
    if (filePath) {
      const args: Map<string, string> = new Map()
      args.set('file_path', filePath)
      const resultJson = executeToolCall('file_scan', args)
      const result = parseToolResult(resultJson)
      riskLevel = toRiskLevel(result.riskLevel)
      agentContent = formatFileScanResult(result)
    } else {
      agentContent = '请提供需要扫描的文件路径，我会帮你检测文件安全性。'
    }
  } else if (isNetworkQuery(lowerInput)) {
    toolName = 'network_monitor'
    const checkType = lowerInput.indexOf('详细') >= 0 || lowerInput.indexOf('全面') >= 0 ? 'full' : 'quick'
    const args: Map<string, string> = new Map()
    args.set('check_type', checkType)
    const resultJson = executeToolCall('network_monitor', args)
    const result = parseToolResult(resultJson)
    riskLevel = toRiskLevel(result.riskLevel)
    agentContent = formatNetworkMonitorResult(result)
  } else if (isPrivacyQuery(lowerInput)) {
    toolName = 'privacy_health_check'
    const args: Map<string, string> = new Map()
    const resultJson = executeToolCall('privacy_health_check', args)
    const result = parseToolResult(resultJson)
    riskLevel = toRiskLevel(result.riskLevel)
    agentContent = formatPrivacyHealthResult(result)
  } else if (isWifiQuery(lowerInput)) {
    toolName = 'wifi_check'
    const args: Map<string, string> = new Map()
    const resultJson = executeToolCall('wifi_check', args)
    const result = parseToolResult(resultJson)
    riskLevel = toRiskLevel(result.riskLevel)
    agentContent = formatWifiCheckResult(result)
  } else if (isReportQuery(lowerInput)) {
    toolName = 'security_report'
    const report: SecurityReport = generateSecurityReport()
    riskLevel = report.overallRiskLevel
    agentContent = formatReportAsText(report)
  } else if (isDeviceQuery(lowerInput)) {
    toolName = 'device_security_check'
    const args: Map<string, string> = new Map()
    const resultJson = executeToolCall('device_security_check', args)
    const result = parseToolResult(resultJson)
    riskLevel = toRiskLevel(result.riskLevel)
    agentContent = formatDeviceSecurityResult(result)
  } else if (isGreeting(lowerInput)) {
    const timeGreeting = getTimeGreeting()
    agentContent = `${timeGreeting}我是谛听，你的 24/7 端侧安全守护伙伴。\n\n## 我可以帮你\n\n• 🔗 检测链接安全性 — 直接发链接给我\n• 🔐 分析应用权限 — "检查XX应用权限"\n• 📁 扫描文件安全 — "扫描文件 xxx"\n• 🌐 监控网络安全 — "检查网络"\n• 📶 Wi-Fi安全检测 — "检查Wi-Fi安全"\n• 🛡️ 隐私健康评分 — "全面检查"\n• 📋 生成安全报告 — "生成安全报告"\n• 📱 查看设备安全状态 — "设备安全"\n\n有什么安全方面的问题，随时问我！`
  } else if (isSecurityKnowledgeQuery(lowerInput)) {
    agentContent = generateSecurityKnowledgeResponse(lowerInput)
  } else {
    agentContent = generateGeneralResponse(lowerInput)
  }

    const agentMsg = new ChatMessage(nextId + 1, MessageRole.AGENT, agentContent, riskLevel)
  newMessages.push(agentMsg)

  const toolTarget = getToolTarget(lowerInput, userInput)
  if (toolName.length > 0) {
    addSecurityRecord(toolName, riskLevel, agentContent.substring(0, 100), toolTarget)
  }

  return newMessages
}

function parseToolResult(json: string): ToolResultData {
  try {
    const result = new ToolResultData()
    const obj: Record<string, Object> = JSON.parse(json) as Record<string, Object>
    result.tool = (obj['tool'] ?? '') as string
    result.riskLevel = (obj['riskLevel'] ?? 'safe') as string
    result.summary = (obj['summary'] ?? '') as string
    const details = obj['details']
    if (details) {
      const d = details as Record<string, Object>
      result.details.url = (d['url'] ?? '') as string
      result.details.sslValid = (d['sslValid'] ?? true) as boolean
      result.details.isPhishing = (d['isPhishing'] ?? false) as boolean
      result.details.reputation = (d['reputation'] ?? '') as string
      result.details.packageName = (d['packageName'] ?? '') as string
      result.details.permissionCount = (d['permissionCount'] ?? 0) as number
      result.details.filePath = (d['filePath'] ?? '') as string
      result.details.isSuspicious = (d['isSuspicious'] ?? false) as boolean
      result.details.currentNetwork = (d['currentNetwork'] ?? '') as string
      result.details.networkType = (d['networkType'] ?? '') as string
      result.details.isSecure = (d['isSecure'] ?? true) as boolean
      result.details.isPortal = (d['isPortal'] ?? false) as boolean
      result.details.proxyDetected = (d['proxyDetected'] ?? false) as boolean
      result.details.vpnActive = (d['vpnActive'] ?? false) as boolean
      result.details.overallScore = (d['overallScore'] ?? 100) as number
      const riskPerms = d['riskPermissions']
      if (riskPerms) {
        const arr = riskPerms as string[]
        for (const p of arr) {
          result.details.riskPermissions.push(p)
        }
      }
      const threats = d['threats']
      if (threats) {
        const arr = threats as string[]
        for (const t of arr) {
          result.details.threats.push(t)
        }
      }
      const categories = d['categories']
      if (categories) {
        const arr = categories as Record<string, Object>[]
        for (const cat of arr) {
          const cs = new CategoryScore()
          cs.name = (cat['name'] ?? '') as string
          cs.score = (cat['score'] ?? 100) as number
          const issues = cat['issues']
          if (issues) {
            const issueArr = issues as string[]
            for (const iss of issueArr) {
              cs.issues.push(iss)
            }
          }
          result.details.categories.push(cs)
        }
      }
      const deviceStatus = d['deviceStatus']
      if (deviceStatus) {
        const arr = deviceStatus as Record<string, Object>[]
        for (const ds of arr) {
          const item = new MonitorStatusItem()
          item.name = (ds['name'] ?? '') as string
          item.icon = (ds['icon'] ?? '') as string
          item.active = (ds['active'] ?? false) as boolean
          item.description = (ds['description'] ?? '') as string
          item.liveInfo = (ds['liveInfo'] ?? '') as string
          result.details.deviceStatus.push(item)
        }
      }
    }
    return result
  } catch (e) {
    const fallback = new ToolResultData()
    fallback.riskLevel = 'suspicious'
    fallback.summary = '分析过程中出现异常，无法确定安全性，请谨慎对待。'
    return fallback
  }
}

function isLinkQuery(lowerInput: string, input: string): boolean {
  const keywords = ['链接', '网址', 'url', '网站', '安全吗', '钓鱼', '可疑', '检测链接',
    '检查链接', '链接安全', '这个链接', '这个网址', '这个网站', '点开', '打开链接']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return input.indexOf('http://') >= 0 || input.indexOf('https://') >= 0
}

function isPermissionQuery(lowerInput: string): boolean {
  const keywords = ['权限', '应用权限', 'app权限', '安装权限', '索权', '过度权限',
    '权限分析', '检查权限', '应用安全', '读取通讯录', '读取位置', '获取位置',
    '相机权限', '麦克风权限']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return false
}

function isFileQuery(lowerInput: string): boolean {
  const keywords = ['文件', '扫描文件', '文件安全', '病毒', '木马', '恶意文件',
    '文件检测', '扫描病毒', 'apk安全', '安装包']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return false
}

function isNetworkQuery(lowerInput: string): boolean {
  const keywords = ['网络', '网络状态', '网络安全', '蹭网', '公共wifi', '网络检测',
    '检查网络', '网速', '代理', 'vpn状态', '当前网络', '在线']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return false
}

function isPrivacyQuery(lowerInput: string): boolean {
  const keywords = ['全面检查', '隐私', '隐私健康', '健康评分', '体检', '全面体检',
    '安全体检', '综合评估', '全面评估', '安全状态', '整体安全']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return false
}

function isWifiQuery(lowerInput: string): boolean {
  const keywords = ['wifi安全', 'wi-fi安全', '无线安全', 'wifi检查', 'wifi检测',
    'wifi风险', '无线网络', 'wifi状态', '当前wifi', '连接wifi']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return false
}

function isReportQuery(lowerInput: string): boolean {
  const keywords = ['安全报告', '生成报告', '导出报告', '报告总结', '总体评估',
    '安全评估', '安全报告', '出个报告', '来份报告', '安全总结']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return false
}

function isDeviceQuery(lowerInput: string): boolean {
  const keywords = ['设备安全', '设备状态', '守护状态', '监控状态', '手机安全',
    '手机状态', '设备监控', '守护概览', '安全概览', '电池状态', '蓝牙状态',
    'sim卡', 'sim状态', 'usb状态', '耗电', '温度', '手机监控', '设备概览']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return false
}

function isGreeting(lowerInput: string): boolean {
  const greetings = ['你好', '嗨', 'hello', 'hi', '你是谁', '介绍']
  for (const g of greetings) {
    if (lowerInput.indexOf(g) >= 0) {
      return true
    }
  }
  return false
}

function isSecurityKnowledgeQuery(lowerInput: string): boolean {
  const keywords = ['什么是', '科普', '解释', 'ssl', 'tls', '加密', '钓鱼', '恶意软件',
    '木马', '病毒', '勒索', 'wifi', '蓝牙', '隐私', '密码', 'vpn', '2fa',
    '双重认证', '社工', '漏洞', '补丁', 'root', '越狱', '泄露', '数据泄露',
    '二维码', '扫码', '公共wifi', '蹭网', '应用安全', '备份',
    'ai安全', '人工智能', '深度伪造', 'deepfake', '人脸', '语音克隆',
    '物联网', 'iot', '智能家居', 'spyware', '键盘记录',
    '模拟钓鱼', 'phishing', '加密货币', '挖矿', '矿机',
    '零信任', '防火墙', '杀毒', '安全软件']
  for (const kw of keywords) {
    if (lowerInput.indexOf(kw) >= 0) {
      return true
    }
  }
  return false
}

function extractPackageName(input: string): string {
  const patterns = ['com.', 'org.', 'net.', 'cn.']
  for (const p of patterns) {
    const idx = input.indexOf(p)
    if (idx >= 0) {
      const end = input.indexOf(' ', idx)
      return end >= 0 ? input.substring(idx, end) : input.substring(idx)
    }
  }
  const nameMap: Map<string, string> = new Map([
    ['微信', 'com.tencent.mm'], ['淘宝', 'com.taobao.taobao'],
    ['支付宝', 'com.eg.android.AlipayGphone'], ['抖音', 'com.ss.android.ugc.aweme'],
    ['微博', 'com.sina.weibo'], ['京东', 'com.jingdong.app.mall'],
    ['百度地图', 'com.baidu.BaiduMap'], ['百度', 'com.baidu.searchbox'],
    ['高德地图', 'com.autonavi.minimap'], ['高德', 'com.autonavi.minimap'],
    ['美图', 'com.meitu.meiyancamera'], ['美图秀秀', 'com.meitu.meiyancamera'],
    ['爱奇艺', 'com.qiyi.video'], ['qq音乐', 'com.tencent.qqmusic'],
    ['QQ音乐', 'com.tencent.qqmusic'], ['拼多多', 'com.xunmeng.pinduoduo'],
    ['美团', 'com.sankuai.meituan'], ['大众点评', 'com.dianping.v1'],
    ['哔哩哔哩', 'tv.danmaku.bili'], ['B站', 'tv.danmaku.bili'],
    ['网易云音乐', 'com.netease.cloudmusic'], ['快手', 'com.smile.gifmaker'],
    ['滴滴', 'com.sdu.didi.psnger'], ['携程', 'ctrip.android.view'],
    ['头条', 'com.ss.android.article.news'], ['今日头条', 'com.ss.android.article.news'],
    ['小红书', 'com.xingin.xhs'], ['手机百度', 'com.baidu.searchbox']
  ])
  const lower = input.toLowerCase()
  let foundPkg = ''
  nameMap.forEach((pkg: string, name: string) => {
    if (foundPkg.length === 0 && lower.indexOf(name.toLowerCase()) >= 0) {
      foundPkg = pkg
    }
  })
  return foundPkg
}

function extractFilePath(input: string): string {
  const pathPatterns = ['/data/', '/storage/', '/sdcard/']
  for (const p of pathPatterns) {
    const idx = input.indexOf(p)
    if (idx >= 0) {
      const end = input.indexOf(' ', idx)
      return end >= 0 ? input.substring(idx, end) : input.substring(idx)
    }
  }
  const extPatterns = ['.apk', '.exe', '.doc', '.xls', '.pdf', '.zip']
  for (const ext of extPatterns) {
    const idx = input.indexOf(ext)
    if (idx >= 0) {
      const start = Math.max(0, input.lastIndexOf(' ', idx) + 1)
      return input.substring(start, idx + ext.length)
    }
  }
  return ''
}

function riskEmoji(level: string): string {
  if (level === 'safe') { return '🟢' }
  if (level === 'suspicious') { return '🟡' }
  if (level === 'dangerous') { return '🔴' }
  if (level === 'critical') { return '⛔' }
  return '🟢'
}

function formatLinkCheckResult(result: ToolResultData): string {
  const risk = riskEmoji(result.riskLevel)
  return `## ${risk} 链接安全检测报告\n\n---\n\n🔗 目标链接\n${result.details.url.length > 0 ? result.details.url : '未提供'}\n\n📋 检测结果\n• SSL/TLS: ${result.details.sslValid ? '✅ 有效' : '❌ 无效/未启用'}\n• 钓鱼特征: ${result.details.isPhishing ? '⚠️ 检测到' : '✅ 未发现'}\n\n> ${result.summary}\n\n💡 建议：不要在可疑网站上输入任何个人信息。\n\n需要我进一步分析或帮你做其他检查吗？`
}

function formatPermissionScanResult(result: ToolResultData): string {
  const risk = riskEmoji(result.riskLevel)
  return `## ${risk} 应用权限分析报告\n\n---\n\n📦 应用\n${result.details.packageName.length > 0 ? result.details.packageName : '未知'}\n\n📋 权限概况\n• 总权限数: ${result.details.permissionCount}\n• 风险权限: ${result.details.riskPermissions.length} 项\n\n> ${result.summary}\n\n💡 建议：在系统设置中审查该应用的权限，关闭不必要的敏感权限。\n\n需要我帮你检查其他应用吗？`
}

function formatFileScanResult(result: ToolResultData): string {
  const risk = riskEmoji(result.riskLevel)
  return `## ${risk} 文件安全扫描报告\n\n---\n\n📁 文件\n${result.details.filePath.length > 0 ? result.details.filePath : '未知'}\n\n📋 检测结果\n• 威胁检测: ${result.details.isSuspicious ? '⚠️ 发现可疑特征' : '✅ 未发现威胁'}\n• 威胁类型: ${result.details.threats.length > 0 ? result.details.threats.join('、') : '无'}\n\n> ${result.summary}\n\n💡 建议：不要打开来源不明的文件，尤其是 .apk 和 .exe。\n\n需要我扫描其他文件吗？`
}

function formatNetworkMonitorResult(result: ToolResultData): string {
  const risk = riskEmoji(result.riskLevel)
  return `## ${risk} 网络安全检测报告\n\n---\n\n📡 当前网络\n${result.details.currentNetwork}\n\n📋 检测结果\n• 连接安全: ${result.details.isSecure ? '✅ 安全' : '⚠️ 存在风险'}\n• 代理检测: ${result.details.proxyDetected ? '⚠️ 检测到代理' : '✅ 无代理'}\n• VPN状态: ${result.details.vpnActive ? '✅ 已启用' : '未启用'}\n\n> ${result.summary}\n\n💡 建议：在不可信网络上避免输入密码和支付信息。\n\n需要我进行更详细的网络诊断吗？`
}

function formatPrivacyHealthResult(result: ToolResultData): string {
  const risk = riskEmoji(result.riskLevel)
  return `## ${risk} 隐私健康体检报告\n\n---\n\n📊 综合评分\n${result.details.overallScore}/100\n\n> ${result.summary}\n\n💡 定期体检能及时发现潜在风险。你可以随时问我具体的安全问题。`
}

function formatWifiCheckResult(result: ToolResultData): string {
  const risk = riskEmoji(result.riskLevel)
  return `## ${risk} Wi-Fi 安全检测报告\n\n---\n\n📡 当前网络\n${result.details.currentNetwork}\n\n📋 检测结果\n• 安全状态: ${result.details.isSecure ? '✅ 安全' : '⚠️ 存在风险'}\n\n> ${result.summary}\n\n💡 建议在开放Wi-Fi上使用VPN，不要进行支付操作。\n\n需要我做更全面的网络安全检查吗？`
}

function formatDeviceSecurityResult(result: ToolResultData): string {
  const risk = riskEmoji(result.riskLevel)
  return `## ${risk} 设备安全状态\n\n---\n\n> ${result.summary}\n\n💡 想了解某项守护的详情，直接问我！`
}

function generateSecurityKnowledgeResponse(lowerInput: string): string {
  if (lowerInput.indexOf('xss') >= 0) {
    return '## XSS 跨站脚本攻击\n\nXSS（跨站脚本攻击）是一种常见的网页安全漏洞。\n\n简单理解：黑客在网页里偷偷塞入恶意代码，当你打开这个网页时，代码就在你的浏览器里运行了，可能会偷走你的登录信息。\n\n### 防护建议\n\n• 不要点击来路不明的链接\n• 不要在不信任的网页上输入账号密码\n• 保持浏览器更新\n\n有什么其他安全问题想了解的？'
  }
  if (lowerInput.indexOf('mitm') >= 0 || lowerInput.indexOf('中间人') >= 0) {
    return '## 🕵️ 中间人攻击 (MITM)\n\nMITM（中间人攻击）就像有人在你和对方之间偷听和篡改消息。\n\n简单理解：你在公共 Wi-Fi 上网购，黑客可能截获你的支付信息，甚至修改你看到的商品价格。\n\n### 防护建议\n\n• 在公共 Wi-Fi 上避免输入敏感信息\n• 使用 HTTPS 网站（浏览器地址栏有锁图标）\n• 必要时使用 VPN 加密通信\n\n还有其他想了解的安全知识吗？'
  }
  if (lowerInput.indexOf('证书') >= 0 || lowerInput.indexOf('ssl') >= 0 || lowerInput.indexOf('tls') >= 0) {
    return '## 🔐 SSL/TLS 证书\n\nSSL/TLS 证书就像是网站的"身份证"。\n\n简单理解：HTTPS 网站使用 SSL/TLS 证书来证明"我是真正的官网，不是冒牌货"，同时加密你和网站之间的通信，让黑客无法偷听。\n\n### 如何判断证书是否有效\n\n• 浏览器地址栏有锁图标 = 有效\n• 点击锁图标可查看证书详情\n• 如果浏览器提示"证书不可信"，千万别继续访问\n\n> 需要我帮你检查某个网站的安全性吗？'
  }
  if (lowerInput.indexOf('钓鱼') >= 0) {
    return '## 🎣 钓鱼攻击\n\n钓鱼攻击是最常见的网络诈骗手段之一。\n\n简单理解：骗子伪装成银行、快递、客服等给你发短信或邮件，引导你点击假网站输入账号密码，然后偷走你的钱。\n\n### 识别方法\n\n• 看网址：假网站域名通常和真的很像但不一样（如 ta0bao.com）\n• 看内容：催促你"立即操作""账号将被冻结"的多半是骗子\n• 看链接：鼠标悬停看真实地址，不要直接点\n• 看称呼：正规机构不会用"亲爱的用户"这种泛称\n\n> 收到可疑消息？把链接发给我，帮你检测！'
  }
  if (lowerInput.indexOf('勒索') >= 0) {
    return '## 🔒 勒索软件\n\n勒索软件是一种特别狠毒的恶意软件。\n\n简单理解：它会把你的文件全部加密锁住，然后要求你付钱（通常是比特币）才给你解锁。付了钱也不一定能拿回文件！\n\n### 如何防范\n\n• 定期备份重要文件（云端+外部硬盘）\n• 不要打开陌生人发来的附件\n• 保持系统和软件更新\n• 安装可靠的安全软件\n\n### 万一中招\n\n• 不要付钱！付钱不能保证恢复\n• 立即断网防止扩散\n• 用备份恢复文件\n• 寻求专业安全机构帮助'
  }
  if (lowerInput.indexOf('密码') >= 0) {
    return '## 🔑 密码安全\n\n密码安全是保护个人信息的第一道防线。\n\n### 好密码的标准\n\n• 长度至少12位\n• 混合大小写字母、数字、特殊符号\n• 不要用生日、手机号、连续数字\n• 每个网站用不同密码\n\n### 实用技巧\n\n• 用一句你记得住的话的首字母组合（如"我2024年在北京住"→W2024nzBZ!）\n• 使用密码管理器生成和保存密码\n• 开启双重认证（2FA），即使密码泄露也多一层保护\n• 定期更换重要账户的密码\n\n> 我可以帮你检查密码是否已泄露，发给我试试？'
  }
  if (lowerInput.indexOf('vpn') >= 0) {
    return '## 🌐 VPN 虚拟专用网络\n\nVPN 就像一条加密隧道。\n\n简单理解：你和网站之间的所有通信都经过一条加密的"隧道"，黑客即使截获也看不懂内容。\n\n### VPN 的作用\n\n• 在公共 Wi-Fi 上保护通信安全\n• 防止运营商查看你的浏览记录\n• 访问地区限制的内容\n\n### 注意事项\n\n• 免费 VPN 可能本身就在收集你的数据\n• 选择有信誉的 VPN 服务\n• VPN 不是万能的，仍需注意其他安全习惯\n• 在某些地区使用 VPN 需遵守当地法规'
  }
  if (lowerInput.indexOf('2fa') >= 0 || lowerInput.indexOf('双重认证') >= 0 || lowerInput.indexOf('两步验证') >= 0) {
    return '## 🛡️ 双重认证 (2FA)\n\n双重认证 = 密码 + 第二种验证方式。\n\n简单理解：就算别人偷了你的密码，没有你的手机也登不进去，相当于给账户上了双保险。\n\n### 2FA 的类型（安全性从高到低）\n\n• 硬件密钥（YubiKey等）— 最安全\n• 认证器App（如华为验证器）— 很安全\n• 短信验证码 — 有被拦截风险\n• 邮箱验证码 — 一般\n\n### 建议开启2FA的账户\n\n• 银行/支付账户\n• 邮箱\n• 社交媒体主账号\n• 云存储\n\n> 需要我帮你检查其他安全问题吗？'
  }
  if (lowerInput.indexOf('恶意软件') >= 0 || lowerInput.indexOf('木马') >= 0 || lowerInput.indexOf('病毒') >= 0) {
    return '## 🦠 恶意软件\n\n恶意软件是蓄意破坏或窃取信息的程序，常见类型：\n\n• 🦠 病毒：感染其他程序，随程序运行而激活\n• 🐴 木马：伪装成正常软件，偷偷开后门\n• 🔒 勒索软件：加密你的文件要赎金\n• 🕵️ 间谍软件：暗中监控你的操作\n• 📢 广告软件：强制推送广告\n\n### 如何防范\n\n• 只从官方应用商店下载App\n• 不要随意安装来源不明的 APK\n• 不要点击可疑链接或附件\n• 定期检查应用权限（我可以帮你分析！）\n• 保持系统和应用更新\n\n> 怀疑手机有问题？让我帮你做个全面安全体检！'
  }
  if (lowerInput.indexOf('蓝牙') >= 0) {
    return '## 📡 蓝牙安全\n\n蓝牙安全问题不容忽视。\n\n### 常见蓝牙攻击\n\n• Bluesnarfing：未经授权访问蓝牙设备数据\n• Bluejacking：向附近蓝牙设备发送垃圾信息\n• 蓝牙追踪：通过蓝牙信号追踪你的位置\n\n### 防护建议\n\n• 不用时关闭蓝牙\n• 设置蓝牙为"不可发现"模式\n• 不配对不认识的设备\n• 定期检查已配对设备列表，删除不认识的\n• 保持系统更新\n\n> 让我帮你检查设备安全状况？'
  }
  if (lowerInput.indexOf('隐私') >= 0) {
    return '## 🔒 隐私保护\n\n隐私保护是数字时代的必修课。\n\n### 你的隐私可能这样泄露\n\n• App 过度索权（要位置、通讯录、相册等）\n• 公共 Wi-Fi 窃听\n• 社交平台过度分享\n• 数据追踪和画像\n• 旧手机/电脑未彻底清除数据\n\n### 保护隐私的建议\n\n• 最小权限原则：只给App必要的权限\n• 定期检查权限设置（让我帮你分析！）\n• 重置广告标识符\n• 不在社交平台暴露真实位置\n• 重要信息用端到端加密通信\n• 旧设备恢复出厂设置后再处理\n\n> 说"全面检查"，我帮你做一次隐私体检！'
  }
  if (lowerInput.indexOf('社工') >= 0) {
    return '## 🎭 社会工程学攻击\n\n社工攻击 = 骗术 + 心理学。\n\n简单理解：黑客不靠技术漏洞，靠"骗"你来获取信息。比如冒充IT部门打电话让你"验证密码"。\n\n### 常见手法\n\n• 冒充领导/同事要转账或敏感信息\n• 冒充客服说"你的账户异常"\n• 伪造紧急情况制造恐慌\n• 利用好奇心（"看看谁在说你坏话"）\n\n### 防范要点\n\n• 凡是要求提供密码的，一律拒绝\n• 遇到"紧急"要求，先冷静核实\n• 不在电话/聊天中透露敏感信息\n• 通过官方渠道独立验证，不要用对方提供的链接\n\n> 有可疑信息？发给我帮你分析！'
  }
  if (lowerInput.indexOf('root') >= 0 || lowerInput.indexOf('越狱') >= 0) {
    return '## ⚠️ Root/越狱风险\n\nRoot/越狱会打破系统安全沙箱，带来重大风险。\n\n### 风险\n\n• 恶意App可获取最高权限，为所欲为\n• 银行/支付App可能拒绝运行\n• 系统更新可能失败\n• 安全机制被破坏\n\n### 建议\n\n• 普通用户不要 Root/越狱\n• 如确需高级权限，使用官方开发者模式\n• 已 Root 的设备应格外注意安全\n• 只安装可信来源的应用\n\n> 需要我帮你检查设备安全状态吗？'
  }
  if (lowerInput.indexOf('漏洞') >= 0 || lowerInput.indexOf('补丁') >= 0) {
    return '## 🔧 漏洞与补丁\n\n软件漏洞是程序中的安全缺陷，黑客可以利用它入侵系统。\n\n简单理解：就像门锁有个设计缺陷，小偷知道了就能不用钥匙开门。补丁就是厂商发布的"修锁"更新。\n\n### 如何保护自己\n\n• 及时更新操作系统和App\n• 开启自动更新\n• 关注安全新闻，重要漏洞及时修补\n• 不要使用已停止更新的旧版软件\n\n> 我可以帮你检查网络安全，看看当前环境是否有风险。'
  }
  if (lowerInput.indexOf('数据泄露') >= 0 || lowerInput.indexOf('信息泄露') >= 0 || lowerInput.indexOf('泄露') >= 0) {
    return '## 📊 数据泄露\n\n数据泄露是指你的个人信息被未经授权地获取和传播。\n\n### 常见泄露渠道\n\n• 网站被黑客入侵（如你注册过的网站数据库泄露）\n• 钓鱼攻击骗取信息\n• App过度收集并泄露用户数据\n• 社交工程骗取信息\n• 丢失未加密的手机/电脑\n\n### 数据泄露后怎么办\n\n• 立即更改相关账户密码\n• 开启双重认证\n• 监控银行账户异常交易\n• 冻结信用报告（如有必要）\n• 向相关平台举报\n\n### 预防建议\n\n• 每个网站使用不同密码\n• 最小化个人信息提供\n• 定期检查账户活动\n• 使用"生成安全报告"功能了解当前风险状态'
  }
  if (lowerInput.indexOf('二维码') >= 0 || lowerInput.indexOf('扫码') >= 0) {
    return '## 📱 二维码安全\n\n二维码安全是容易被忽视的风险点。\n\n### 二维码陷阱\n\n• 恶意二维码可能跳转到钓鱼网站\n• 可能自动下载恶意软件\n• 可能发起支付请求\n• 隐藏真实URL，你扫码前看不到去哪\n\n### 安全扫码建议\n\n• 只扫来源可信的二维码\n• 扫码后先看URL再决定是否打开\n• 不要扫来历不明的街头广告二维码\n• 支付类二维码只扫官方渠道的\n• 可疑链接发给我帮你检测！\n\n> 记住：二维码就是包装过的链接，同样需要警惕。'
  }
  if (lowerInput.indexOf('公共wifi') >= 0 || lowerInput.indexOf('公共wi-fi') >= 0 || lowerInput.indexOf('蹭网') >= 0) {
    return '## 📶 公共 Wi-Fi 安全\n\n公共Wi-Fi是安全风险最高的上网环境之一。\n\n### 风险\n\n• 开放网络无加密，所有通信可被窃听\n• 同一网络中的黑客可以截获你的数据\n• 伪造的热点（Evil Twin）冒充合法Wi-Fi\n• Portal认证页面可能收集你的信息\n\n### 安全使用公共Wi-Fi\n\n• 不要登录银行/支付账户\n• 不要输入任何密码\n• 关闭文件共享功能\n• 使用HTTPS网站（浏览器有锁图标）\n• 最好使用VPN加密所有通信\n• 用完后"忘记网络"\n\n> 说"检查Wi-Fi安全"，我帮你分析当前Wi-Fi风险！'
  }
  if (lowerInput.indexOf('应用安全') >= 0 || lowerInput.indexOf('下载安全') >= 0 || lowerInput.indexOf('app安全') >= 0) {
    return '## 📲 应用安全\n\n应用安全是移动设备防护的关键环节。\n\n### 风险应用来源\n\n• 第三方应用商店/网站下载的APK\n• 被篡改的正规应用（山寨App）\n• 捆绑恶意软件的"免费"应用\n• 过度索权的应用\n\n### 安全下载建议\n\n• 只从官方应用商店下载（华为应用市场等）\n• 查看应用评分和评论\n• 检查开发者信息是否正规\n• 下载前看权限请求是否合理\n• 定期清理不用的应用\n\n> 我可以帮你分析应用权限是否合理，告诉我应用名称即可！'
  }
  if (lowerInput.indexOf('备份') >= 0 || lowerInput.indexOf('数据备份') >= 0) {
    return '## 💾 数据备份\n\n数据备份是最重要的安全防线之一，很多人忽视了它。\n\n### 为什么备份\n\n• 手机丢失/损坏可以恢复数据\n• 勒索软件加密后可以用备份恢复\n• 误删重要文件可以找回\n• 换新手机时方便迁移\n\n### 备份最佳实践\n\n• 3-2-1原则：3份备份，2种介质，1份异地\n• 重要数据云备份+本地备份\n• 定期验证备份是否可用\n• 备份也要加密保护隐私\n\n> HarmonyOS 自带云备份功能，建议开启自动备份。'
  }
  if (lowerInput.indexOf('ai安全') >= 0 || lowerInput.indexOf('人工智能') >= 0 || lowerInput.indexOf('ai') >= 0) {
    return '## 🤖 AI 安全\n\nAI安全是人工智能时代的新挑战。\n\n### AI带来的安全风险\n\n• 🎭 深度伪造（Deepfake）：AI生成逼真的假视频/音频，可用于诈骗\n• 🎯 AI钓鱼：AI生成高度个性化的钓鱼邮件，更难识别\n• 🕵️ AI辅助攻击：黑客用AI自动发现漏洞、生成恶意代码\n• 📝 隐私泄露：AI训练数据可能包含个人信息\n\n### AI安全防护\n\n• 对视频/音频多一份怀疑，尤其是涉及金钱的\n• 遇到"亲友视频借钱"，务必电话核实\n• 了解AI生成内容的特征（不自然的眨眼、嘴形等）\n• 选择有AI安全防护的应用和平台\n\n> 谛听正在研究端侧AI模型来检测深度伪造内容，敬请期待！'
  }
  if (lowerInput.indexOf('深度伪造') >= 0 || lowerInput.indexOf('deepfake') >= 0 || lowerInput.indexOf('人脸') >= 0 || lowerInput.indexOf('换脸') >= 0) {
    return '## 🎭 深度伪造 (Deepfake)\n\n深度伪造是AI安全的最大威胁之一。\n\n### 什么是深度伪造\n\n• AI分析大量照片/视频后，可以生成以假乱真的人脸视频\n• 可实时换脸，甚至模拟表情和嘴形\n• 已被用于电信诈骗、敲诈勒索、虚假新闻\n\n### 如何识别深度伪造\n\n• 👁️ 面部边缘不自然，有模糊或色差\n• 👁️ 眨眼频率异常（太多或太少）\n• 👁️ 嘴形与声音不完全同步\n• 👁️ 光影方向不一致\n• 👁️ 皮肤纹理过于完美或过于粗糙\n\n### 防范建议\n\n• 视频通话中要求对方做特定动作（转头、遮脸等）\n• 涉及转账的视频验证，额外电话确认\n• 不在社交媒体公开大量清晰正面照\n• 关注AI安全新闻，了解最新检测技术'
  }
  if (lowerInput.indexOf('物联网') >= 0 || lowerInput.indexOf('iot') >= 0 || lowerInput.indexOf('智能家居') >= 0) {
    return '## 🏠 物联网 (IoT) 安全\n\n物联网设备是家庭安全的薄弱环节。\n\n### IoT安全风险\n\n• 🏠 智能摄像头可能被黑客入侵偷窥\n• 🔒 智能门锁可能被远程破解\n• 💡 智能灯泡可能成为入侵Wi-Fi的跳板\n• 🎤 智能音箱可能一直在监听\n\n### IoT安全建议\n\n• 购买大品牌产品，有安全更新保障\n• 首次使用立即修改默认密码\n• 将IoT设备放在独立的Wi-Fi网络（访客网络）\n• 定期更新固件\n• 不用的智能设备断电断网\n• 摄像头不用时物理遮挡\n• 检查设备权限，关闭不需要的麦克风/位置\n\n> 让我帮你检查当前网络安全状况？'
  }
  if (lowerInput.indexOf('加密货币') >= 0 || lowerInput.indexOf('挖矿') >= 0 || lowerInput.indexOf('矿机') >= 0 || lowerInput.indexOf('虚拟货币') >= 0 || lowerInput.indexOf('比特币') >= 0) {
    return '## 💰 加密货币安全\n\n加密货币安全需要格外警惕。\n\n### 常见加密货币骗局\n\n• "保本保收益"的虚拟货币投资 — 100%是骗局\n• 假交易所/假钱包App — 转入即被盗\n• "内幕消息"带单群 — 庄家割韭菜\n• 挖矿木马 — 偷偷用你的手机/电脑挖矿\n• 空气币/传销币 — 没有实际价值\n\n### 安全建议\n\n• 不参与任何"保收益"的虚拟货币投资\n• 只使用知名交易所（注意辨别山寨App）\n• 助记词/私钥离线保存，绝不联网\n• 手机安装安全软件防挖矿木马\n• 下载App前核对开发者信息\n\n> 如果手机异常发热耗电快，可能是挖矿木马，让我帮你检查！'
  }
  if (lowerInput.indexOf('零信任') >= 0 || lowerInput.indexOf('防火墙') >= 0 || lowerInput.indexOf('杀毒') >= 0 || lowerInput.indexOf('安全软件') >= 0) {
    return '## 🛡️ 安全防护体系\n\n### 零信任原则\n\n"永不信任，始终验证" — 不管是内网还是外网，每次访问都要验证身份。\n\n**应用于个人：**\n• 不因为"看起来像"官方就信任 — 独立验证\n• 每个账户独立密码+2FA\n• 最小权限：只给必要的权限\n\n### 防火墙\n\n• 手机上的防火墙 = 系统权限控制 + 网络安全检测\n• HarmonyOS自带应用沙箱和权限管控\n• 第三方防火墙App需谨慎选择\n\n### 杀毒/安全软件\n\n• HarmonyOS自带安全防护（应用审核+沙箱+权限管控）\n• 额外安全软件可能反而增加风险（需获取高权限）\n• 最佳实践：系统防护 + 良好习惯 + 谛听主动守护\n\n> 我可以帮你做一个全面安全体检！'
  }
  if (lowerInput.indexOf('键盘记录') >= 0 || lowerInput.indexOf('spyware') >= 0 || lowerInput.indexOf('间谍软件') >= 0) {
    return '## 🕵️ 键盘记录与间谍软件\n\n键盘记录器和间谍软件是最隐蔽的威胁之一。\n\n### 什么是键盘记录器\n\n• 记录你的每一次按键，窃取密码、银行卡号\n• 可截屏、录制麦克风、追踪位置\n• 通常伪装成正常App或系统服务\n\n### 感染途径\n\n• 安装来路不明的App\n• 点击恶意链接后自动下载\n• 旁人物理接触手机后安装\n\n### 如何检测\n\n• 手机异常发热、耗电快\n• 流量异常增加\n• 出现不认识的App\n• 输入时偶有卡顿（记录器在写入）\n\n### 防护建议\n\n• 只从官方商店安装App\n• 定期检查应用列表\n• 使用系统自带输入法（第三方输入法可能记录输入）\n• 重要操作用指纹/面容代替密码\n\n> 让我帮你检查当前权限和安全状态！'
  }
  return '## 📚 安全知识库\n\n安全知识方面的问题，我尽量用简单的方式解释。\n\n### 你可以问我\n\n• 🎣 钓鱼攻击 | 🦠 恶意软件/病毒/木马 | 🔒 勒索软件\n• 🔑 密码安全 | 🛡️ 双重认证(2FA) | 🌐 VPN\n• 📡 蓝牙安全 | 📱 隐私保护 | 🎭 社工攻击\n• 🔐 SSL/TLS证书 | ⚔️ XSS | 🕵️ 中间人攻击\n• ⚠️ Root/越狱风险 | 🔧 漏洞与补丁 | 📊 数据泄露\n• 📱 二维码安全 | 📶 公共Wi-Fi | 📲 应用安全\n• 💾 数据备份 | 🤖 AI安全 | 🎭 深度伪造\n• 🏠 物联网/IoT | 💰 加密货币安全 | 🛡️ 零信任/防火墙/杀毒\n• 🕵️ 键盘记录/间谍软件\n\n> 告诉我你感兴趣的话题！'
}

function generateGeneralResponse(lowerInput: string): string {
  if (lowerInput.indexOf('谢') >= 0 || lowerInput.indexOf('thank') >= 0) {
    return '> 不客气！守护你的数字安全是我一直在做的事。有任何安全方面的疑问，随时找我。'
  }
  if (lowerInput.indexOf('帮') >= 0 && (lowerInput.indexOf('忙') >= 0 || lowerInput.indexOf('助') >= 0)) {
    return '当然可以！我可以帮你做这些：\n\n• 🔗 检测链接安全性 — 直接发链接给我\n• 🔐 分析应用权限 — 告诉我应用名称\n• 📁 扫描文件安全 — 提供文件路径\n• 🌐 监控网络安全 — 说"检查网络"\n• 📶 Wi-Fi安全检测 — 说"检查Wi-Fi"\n• 🛡️ 隐私健康评分 — 说"全面检查"\n• 📋 生成安全报告 — 说"生成报告"\n• 📱 查看设备安全 — 说"设备安全"\n\n你想做什么？'
  }
  if (lowerInput.indexOf('怎么样') >= 0 || lowerInput.indexOf('安全吗') >= 0 || lowerInput.indexOf('安全不') >= 0) {
    return '让我帮你做一个快速安全检查吧！\n\n• 发送链接给我检测\n• 说"检查网络"看当前网络安全\n• 说"全面检查"做隐私体检\n• 说"检查Wi-Fi"看无线安全\n\n> 或告诉我你具体担心的内容。'
  }
  if (lowerInput.indexOf('害怕') >= 0 || lowerInput.indexOf('担心') >= 0 || lowerInput.indexOf('焦虑') >= 0) {
    return '理解你的担忧！主动关注安全是很好的习惯。\n\n### 建议先做一个全面体检\n\n• 说"全面检查" — 5维度隐私健康评分\n• 说"检查网络" — 看当前网络是否安全\n• 说"检查Wi-Fi" — 确认Wi-Fi加密状态\n\n> 有任何具体的安全疑虑，告诉我，我来帮你分析。'
  }
  return '我理解你的问题。作为安全守护 Agent，我最擅长的是安全相关的事务。\n\n### 你可以\n\n• 🔗 发链接给我检测安全性\n• 🔐 问我某个应用权限是否合理\n• 📁 让我扫描文件\n• 🌐 检查当前网络安全\n• 🛡️ 做一次全面隐私体检\n• 📱 查看设备安全状态\n• 📚 问我安全知识，比如"什么是钓鱼攻击"？\n\n> 告诉我你需要什么帮助！'
}

function getToolTarget(lowerInput: string, input: string): string {
  const urls = extractUrls(input)
  if (urls.length > 0) {
    return urls[0]
  }
  const pkg = extractPackageName(input)
  if (pkg.length > 0) {
    return pkg
  }
  const fp = extractFilePath(input)
  if (fp.length > 0) {
    return fp
  }
  return ''
}

export function getTimeGreeting(): string {
  const hour = new Date().getHours()
  if (hour >= 5 && hour < 9) { return '早上好！🌅 ' }
  if (hour >= 9 && hour < 12) { return '上午好！☕ ' }
  if (hour >= 12 && hour < 14) { return '中午好！🍱 ' }
  if (hour >= 14 && hour < 18) { return '下午好！💻 ' }
  if (hour >= 18 && hour < 22) { return '晚上好！🌙 ' }
  return '夜深了，注意安全也注意休息！🦉 '
}
