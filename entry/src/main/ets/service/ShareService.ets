import { generateSecurityReport, formatReportAsText } from './SecurityReport'
import { common } from '@kit.AbilityKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN = 0xF000
const TAG = 'DiTingShare'

export function shareText(context: common.UIAbilityContext, text: string): void {
  try {
    const shareData = new systemShare.SharedData({
      utd: utd.UniformDataType.PLAIN_TEXT,
      content: text
    })
    const controller = new systemShare.ShareController(shareData)
    controller.on('dismiss', () => {
      hilog.info(DOMAIN, TAG, 'Share panel closed')
    })
    controller.show(context, {
      previewMode: systemShare.SharePreviewMode.DETAIL,
      selectionMode: systemShare.SelectionMode.SINGLE
    })
  } catch (err) {
    hilog.error(DOMAIN, TAG, `Share failed: ${(err as Error).message}`)
  }
}

export function shareSecurityReport(context: common.UIAbilityContext): void {
  const text = getReportText()
  shareText(context, text)
}

export function getReportText(): string {
  const report = generateSecurityReport()
  return formatReportAsText(report)
}
