export const APP_VERSION = '1.3.0'
export const APP_NAME = '谛听 · 安全守护'
export const APP_SLOGAN = '端侧优先 · 主动守护 · 零门槛'
export const APP_TEAM = '万星辉 · 董贯霖 · 李明楠'
export const APP_PRIVACY = '所有安全分析均在设备端完成，绝不上传你的数据'

export class SecurityScoreParams {
  totalChecks: number = 0
  dangerousCount: number = 0
  suspiciousCount: number = 0
  wifiSecure: boolean = true
  anyMonitorActive: boolean = true
}

export function calcSecurityScore(params: SecurityScoreParams): number {
  if (params.totalChecks === 0) {
    return 100
  }
  const riskRatio = (params.dangerousCount * 3 + params.suspiciousCount) / params.totalChecks
  let score = Math.max(0, Math.min(100, Math.floor(100 - riskRatio * 50)))
  if (!params.wifiSecure) {
    score = Math.max(0, score - 15)
  }
  if (!params.anyMonitorActive) {
    score = Math.max(0, score - 10)
  }
  return score
}
