import { notificationManager } from '@kit.NotificationKit'
import { RiskLevel } from '../model/ChatModel'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0xF000
const TAG = 'DiTingNotification'

let slotCreated = false
let notifCounter = 0
let slotPromise: Promise<void> | null = null

async function ensureSlot(): Promise<void> {
  if (slotCreated) {
    return
  }
  if (slotPromise) {
    await slotPromise
    return
  }
  slotPromise = (async (): Promise<void> => {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SOCIAL_COMMUNICATION)
      slotCreated = true
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Slot creation skipped: ${(err as Error).message}`)
    } finally {
      slotPromise = null
    }
  })()
  await slotPromise
}

export function sendSecurityAlert(title: string, content: string, riskLevel: RiskLevel): void {
  ensureSlot().then(() => {
    try {
      const notificationId = ++notifCounter
      const notificationRequest: notificationManager.NotificationRequest = {
        id: notificationId,
        notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: content
          }
        } as notificationManager.NotificationContent,
        isOngoing: false,
        isAlertOnce: false
      }
      notificationManager.publish(notificationRequest).then(() => {
        hilog.info(DOMAIN, TAG, `Alert published: ${title}`)
      }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, `Publish failed: ${err.message}`)
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Notification error: ${(err as Error).message}`)
    }
  }).catch(() => {})
}

export function formatAlertTitle(riskLevel: RiskLevel): string {
  if (riskLevel === RiskLevel.SUSPICIOUS) { return '🟡 谛听·可疑提醒' }
  if (riskLevel === RiskLevel.DANGEROUS) { return '🔴 谛听·安全告警' }
  if (riskLevel === RiskLevel.CRITICAL) { return '🚨 谛听·紧急告警' }
  return '🛡️ 谛听·安全通知'
}
