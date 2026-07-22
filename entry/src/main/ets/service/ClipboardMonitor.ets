import { pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ChatMessage, MessageRole, RiskLevel } from '../model/ChatModel';
import { sendSecurityAlert, formatAlertTitle } from './NotificationService';
import { extractUrls } from './UrlUtils';
import { processUserInput } from './AgentService';
import { setMonitorActive } from './MonitorOrchestrator';

const DOMAIN = 0xF000;
const TAG = 'DiTingClipboard';
const DEBOUNCE_MS = 1500;

class ClipboardMonitorState {
  lastChangeCount: number = 0
  isMonitoring: boolean = false
  sysPasteboard: pasteboard.SystemPasteboard | null = null
  onUrlDetected: ((url: string, message: ChatMessage) => void) | null = null
  lastProcessedUrl: string = ''
  lastProcessTime: number = 0
  debounceTimer: number = -1
  msgIdCounter: number = 0
}

const state = new ClipboardMonitorState()

export function startClipboardMonitor(callback: (url: string, message: ChatMessage) => void): void {
  if (state.isMonitoring) {
    hilog.info(DOMAIN, TAG, 'Clipboard monitor already running')
    return
  }

  state.onUrlDetected = callback
  state.isMonitoring = true

  try {
    state.sysPasteboard = pasteboard.getSystemPasteboard()
    state.lastChangeCount = state.sysPasteboard.getChangeCount()

    state.sysPasteboard.on('update', () => {
      hilog.info(DOMAIN, TAG, 'Clipboard content updated')
      if (state.debounceTimer >= 0) {
        clearTimeout(state.debounceTimer)
      }
      state.debounceTimer = setTimeout(() => {
        handleClipboardChange()
        state.debounceTimer = -1
      }, DEBOUNCE_MS)
    })

    setMonitorActive('clipboard', true)
    hilog.info(DOMAIN, TAG, 'Clipboard monitor started')
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `Failed to start clipboard monitor: ${e.message}`)
    state.isMonitoring = false
  }
}

export function stopClipboardMonitor(): void {
  if (!state.isMonitoring || !state.sysPasteboard) {
    return
  }

  try {
    state.sysPasteboard.off('update')
    if (state.debounceTimer >= 0) {
      clearTimeout(state.debounceTimer)
      state.debounceTimer = -1
    }
    state.isMonitoring = false
    state.onUrlDetected = null
    state.sysPasteboard = null
    setMonitorActive('clipboard', false)
    hilog.info(DOMAIN, TAG, 'Clipboard monitor stopped')
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `Failed to stop clipboard monitor: ${e.message}`)
  }
}

function handleClipboardChange(): void {
  if (!state.sysPasteboard) {
    return
  }

  try {
    const currentCount = state.sysPasteboard.getChangeCount()

    if (currentCount === state.lastChangeCount) {
      return
    }
    state.lastChangeCount = currentCount

    const hasType = state.sysPasteboard.hasDataType(pasteboard.MIMETYPE_TEXT_PLAIN)
    if (!hasType) {
      return
    }

    state.sysPasteboard.getData().then((pasteData: pasteboard.PasteData) => {
      const now = Date.now()
      const text = pasteData.getPrimaryText()
      if (!text || text.length === 0) {
        return
      }

      const urls = extractUrls(text)
      if (urls.length === 0) {
        return
      }

      for (let i = 0; i < urls.length && i < 3; i++) {
        const url = urls[i]
        if (url === state.lastProcessedUrl && now - state.lastProcessTime < 5000) {
          hilog.info(DOMAIN, TAG, 'Duplicate URL, skipping')
          continue
        }

        state.lastProcessedUrl = url
        state.lastProcessTime = now

        hilog.info(DOMAIN, TAG, `URL detected in clipboard: ${url.substring(0, 80)}`)

        state.msgIdCounter += 2
        const fakeHistory: ChatMessage[] = [
          new ChatMessage(state.msgIdCounter - 1, MessageRole.USER, `帮我检测这个链接的安全性：${url}`)
        ]
        const newMessages = processUserInput(`帮我检测这个链接的安全性：${url}`, fakeHistory)
        const agentMsg = newMessages[newMessages.length - 1]

        if (agentMsg && agentMsg.role === MessageRole.AGENT) {
          if (state.onUrlDetected) {
            state.onUrlDetected(url, agentMsg)
          }

          if (agentMsg.riskLevel === RiskLevel.DANGEROUS || agentMsg.riskLevel === RiskLevel.CRITICAL) {
            sendSecurityAlert(
              formatAlertTitle(agentMsg.riskLevel),
              `检测到可疑链接：${url}\n${agentMsg.content.substring(0, 80)}`,
              agentMsg.riskLevel
            )
          }
        }
      }
    }).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `Failed to read clipboard: ${err.message}`)
    })
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `Clipboard change handler error: ${e.message}`)
  }
}

export function isMonitoring(): boolean {
  return state.isMonitoring
}
