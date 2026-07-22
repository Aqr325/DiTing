import { RiskLevel } from '../model/ChatModel'
import { addSecurityRecord } from './SecurityHistory'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0xF000
const TAG = 'DiTingOrchestrator'

export class MonitorStatus {
  name: string = ''
  active: boolean = false
  icon: string = ''
  description: string = ''
}

class OrchestratorState {
  monitors: Map<string, MonitorStatus> = new Map()
  onAlert: ((message: string, riskLevel: RiskLevel, toolName: string) => void) | null = null
  initialized: boolean = false
}

const state = new OrchestratorState()

export function initMonitorOrchestrator(onAlert: (message: string, riskLevel: RiskLevel, toolName: string) => void): void {
  if (state.initialized) {
    return
  }
  state.onAlert = onAlert
  state.initialized = true

  const names: string[] = ['clipboard', 'network', 'app_lifecycle', 'battery_usb', 'bluetooth', 'sim']
  const icons: string[] = ['📋', '🌐', '📱', '🔋', '📶', '📡']
  const descs: string[] = ['剪贴板守护', '网络守护', '应用守护', '电池USB守护', '蓝牙守护', 'SIM卡守护']

  state.monitors = new Map()
  for (let i = 0; i < names.length; i++) {
    const m = new MonitorStatus()
    m.name = names[i]
    m.icon = icons[i]
    m.description = descs[i]
    m.active = false
    state.monitors.set(names[i], m)
  }
}

export function isMonitorOrchestratorInitialized(): boolean {
  return state.initialized
}

export function setMonitorActive(name: string, active: boolean): void {
  const m = state.monitors.get(name)
  if (m) {
    m.active = active
    hilog.info(DOMAIN, TAG, `Monitor ${name} ${active ? 'activated' : 'deactivated'}`)
  }
}

export function getMonitorStatus(name: string): MonitorStatus {
  const m = state.monitors.get(name)
  if (m) {
    return m
  }
  return new MonitorStatus()
}

export function getAllMonitorStatus(): MonitorStatus[] {
  const result: MonitorStatus[] = []
  state.monitors.forEach((m: MonitorStatus) => {
    result.push(m)
  })
  return result
}

export function getActiveMonitorCount(): number {
  let count = 0
  state.monitors.forEach((m: MonitorStatus) => {
    if (m.active) {
      count++
    }
  })
  return count
}

export function getActiveMonitorNames(): string[] {
  const names: string[] = []
  state.monitors.forEach((m: MonitorStatus) => {
    if (m.active) {
      names.push(m.name)
    }
  })
  return names
}

export function reportAlert(message: string, riskLevel: RiskLevel, toolName: string): void {
  if (state.onAlert) {
    state.onAlert(message, riskLevel, toolName)
  }
  addSecurityRecord(toolName, riskLevel, message.substring(0, 100), '')
}

export function destroyMonitorOrchestrator(): void {
  state.onAlert = null
  state.initialized = false
}
