export class ChatMessage {
  id: number = 0
  role: MessageRole = MessageRole.USER
  content: string = ''
  timestamp: number = 0
  riskLevel: RiskLevel = RiskLevel.SAFE
  toolCallResult: string = ''

  constructor(id: number, role: MessageRole, content: string, riskLevel: RiskLevel = RiskLevel.SAFE, toolCallResult: string = '') {
    this.id = id
    this.role = role
    this.content = content
    this.timestamp = Date.now()
    this.riskLevel = riskLevel
    this.toolCallResult = toolCallResult
  }
}

export enum MessageRole {
  USER = 'user',
  AGENT = 'agent',
  SYSTEM = 'system'
}

export enum RiskLevel {
  SAFE = 'safe',
  SUSPICIOUS = 'suspicious',
  DANGEROUS = 'dangerous',
  CRITICAL = 'critical'
}

export function toRiskLevel(level: string): RiskLevel {
  if (level === 'suspicious') { return RiskLevel.SUSPICIOUS }
  if (level === 'dangerous') { return RiskLevel.DANGEROUS }
  if (level === 'critical') { return RiskLevel.CRITICAL }
  return RiskLevel.SAFE
}
