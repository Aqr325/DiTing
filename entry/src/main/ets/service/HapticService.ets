import { vibrator } from '@kit.SensorServiceKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { RiskLevel } from '../model/ChatModel'

const DOMAIN = 0xF000
const TAG = 'DiTingHaptic'

export function triggerHaptic(riskLevel: RiskLevel): void {
  try {
    if (riskLevel === RiskLevel.CRITICAL) {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.effect.heavy',
        count: 2
      }, {
        usage: 'notification'
      }).catch(() => {})
    } else if (riskLevel === RiskLevel.DANGEROUS) {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.effect.medium',
        count: 1
      }, {
        usage: 'notification'
      }).catch(() => {})
    } else if (riskLevel === RiskLevel.SUSPICIOUS) {
      vibrator.startVibration({
        type: 'preset',
        effectId: 'haptic.effect.light',
        count: 1
      }, {
        usage: 'notification'
      }).catch(() => {})
    }
  } catch (err) {
    hilog.warn(DOMAIN, TAG, `Haptic not available: ${(err as Error).message}`)
  }
}

export function triggerLightHaptic(): void {
  try {
    vibrator.startVibration({
      type: 'preset',
      effectId: 'haptic.effect.light',
      count: 1
    }, {
      usage: 'touch'
    }).catch(() => {})
  } catch (_err) {
    // ignore
  }
}
