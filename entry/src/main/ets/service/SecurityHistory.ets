import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RiskLevel, toRiskLevel } from '../model/ChatModel'
import { common } from '@kit.AbilityKit'

const DOMAIN = 0xF000
const TAG = 'DiTingHistory'
const PREF_NAME = 'diting_security_history'
const KEY_RECORDS = 'security_records'
const MAX_RECORDS = 200

export class SecurityRecord {
  id: number = 0
  timestamp: number = 0
  toolName: string = ''
  riskLevel: RiskLevel = RiskLevel.SAFE
  summary: string = ''
  target: string = ''

  constructor(id: number, toolName: string, riskLevel: RiskLevel, summary: string, target: string) {
    this.id = id
    this.timestamp = Date.now()
    this.toolName = toolName
    this.riskLevel = riskLevel
    this.summary = summary
    this.target = target
  }
}

class HistoryStore {
  records: SecurityRecord[] = []
  pref: preferences.Preferences | null = null
  nextId: number = 1

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, PREF_NAME)
      const json = await this.pref.get(KEY_RECORDS, '[]') as string
      const parsed: Record<string, Object>[] = JSON.parse(json) as Record<string, Object>[]
      this.records = []
      for (const item of parsed) {
        const record = new SecurityRecord(
          (item['id'] ?? 0) as number,
          (item['toolName'] ?? '') as string,
          toRiskLevel((item['riskLevel'] ?? 'safe') as string),
          (item['summary'] ?? '') as string,
          (item['target'] ?? '') as string
        )
        record.timestamp = (item['timestamp'] ?? Date.now()) as number
        this.records.push(record)
      }
      if (this.records.length > 0) {
        this.nextId = this.records[this.records.length - 1].id + 1
      }
      hilog.info(DOMAIN, TAG, `History loaded: ${this.records.length} records`)
    } catch (err) {
      const e = err as Error
      hilog.error(DOMAIN, TAG, `History init failed: ${e.message}`)
    }
  }

  addRecord(toolName: string, riskLevel: RiskLevel, summary: string, target: string): SecurityRecord {
    const record = new SecurityRecord(this.nextId++, toolName, riskLevel, summary, target)
    this.records.push(record)
    if (this.records.length > MAX_RECORDS) {
      this.records = this.records.slice(this.records.length - MAX_RECORDS)
    }
    this.save()
    return record
  }

  getRecent(count: number): SecurityRecord[] {
    const start = Math.max(0, this.records.length - count)
    return this.records.slice(start).reverse()
  }

  getByRiskLevel(level: RiskLevel): SecurityRecord[] {
    const result: SecurityRecord[] = []
    for (const r of this.records) {
      if (r.riskLevel === level) {
        result.push(r)
      }
    }
    return result.reverse()
  }

  getStats(): HistoryStats {
    const stats = new HistoryStats()
    stats.total = this.records.length
    for (const r of this.records) {
      if (r.riskLevel === RiskLevel.DANGEROUS || r.riskLevel === RiskLevel.CRITICAL) {
        stats.dangerousCount++
      } else if (r.riskLevel === RiskLevel.SUSPICIOUS) {
        stats.suspiciousCount++
      } else {
        stats.safeCount++
      }
    }
    if (this.records.length > 0) {
      const dayMs = 24 * 60 * 60 * 1000
      const now = Date.now()
      for (const r of this.records) {
        if (now - r.timestamp < dayMs) {
          stats.todayCount++
        }
      }
    }
    return stats
  }

  clear(): void {
    this.records = []
    this.nextId = 1
    this.save()
  }

  private save(): void {
    if (!this.pref) {
      return
    }
    if (saveTimer >= 0) {
      clearTimeout(saveTimer)
    }
    const pref = this.pref
    const records = this.records
    saveTimer = setTimeout(() => {
      try {
        const dataArr: SecurityRecordData[] = []
        for (const r of records) {
          const d = new SecurityRecordData()
          d.id = r.id
          d.timestamp = r.timestamp
          d.toolName = r.toolName
          d.riskLevel = r.riskLevel
          d.summary = r.summary
          d.target = r.target
          dataArr.push(d)
        }
        pref.put(KEY_RECORDS, JSON.stringify(dataArr)).then(() => {
          pref.flush().catch((err: Error) => {
            hilog.error(DOMAIN, TAG, `History flush failed: ${err.message}`)
          })
        }).catch((err: Error) => {
          hilog.error(DOMAIN, TAG, `History save failed: ${err.message}`)
        })
      } catch (err) {
        const e = err as Error
        hilog.error(DOMAIN, TAG, `History save failed: ${e.message}`)
      }
      saveTimer = -1
    }, 2000)
  }
}

class SecurityRecordData {
  id: number = 0
  timestamp: number = 0
  toolName: string = ''
  riskLevel: string = 'safe'
  summary: string = ''
  target: string = ''
}

export class HistoryStats {
  total: number = 0
  safeCount: number = 0
  suspiciousCount: number = 0
  dangerousCount: number = 0
  todayCount: number = 0
}

const store = new HistoryStore()
let saveTimer: number = -1

export async function initHistoryStore(context: common.UIAbilityContext): Promise<void> {
  await store.init(context)
}

export function addSecurityRecord(toolName: string, riskLevel: RiskLevel, summary: string, target: string): SecurityRecord {
  return store.addRecord(toolName, riskLevel, summary, target)
}

export function getRecentRecords(count: number): SecurityRecord[] {
  return store.getRecent(count)
}

export function getRecordsByRiskLevel(level: RiskLevel): SecurityRecord[] {
  return store.getByRiskLevel(level)
}

export function getHistoryStats(): HistoryStats {
  return store.getStats()
}

export function clearHistory(): void {
  store.clear()
}
