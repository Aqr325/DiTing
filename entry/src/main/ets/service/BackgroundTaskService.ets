import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import { wantAgent, WantAgent, common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { notificationManager } from '@kit.NotificationKit'

const DOMAIN = 0xF000
const TAG = 'DiTingBgTask'
const BG_TASK_ID = 10001

class BgTaskState {
  isRunning: boolean = false
  wantAgent: WantAgent | null = null
}

const state = new BgTaskState()

export async function startLongRunningTask(context: common.UIAbilityContext): Promise<void> {
  if (state.isRunning) {
    hilog.info(DOMAIN, TAG, 'Background task already running')
    return
  }

  try {
    const agentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: context.abilityInfo.bundleName,
          abilityName: context.abilityInfo.name
        }
      ],
      actionType: wantAgent.OperationType.START_ABILITY,
      requestCode: 0,
      wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    }

    const agent = await wantAgent.getWantAgent(agentInfo)
    state.wantAgent = agent

    await backgroundTaskManager.startBackgroundRunning(context,
      backgroundTaskManager.BackgroundMode.DATA_TRANSFER, agent)

    state.isRunning = true
    hilog.info(DOMAIN, TAG, 'Long running background task started')

    const req: notificationManager.NotificationRequest = {
      id: BG_TASK_ID,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: '谛听·安全守护运行中',
          text: '正在为你守护设备安全，检测链接和网络安全'
        }
      } as notificationManager.NotificationContent
    }
    notificationManager.publish(req).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `Bg notification failed: ${err.message}`)
    })
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `startBackgroundRunning failed: ${e.message}`)
  }
}

export async function stopLongRunningTask(context: common.UIAbilityContext): Promise<void> {
  if (!state.isRunning) {
    return
  }

  try {
    await backgroundTaskManager.stopBackgroundRunning(context)
    state.isRunning = false
    state.wantAgent = null
    hilog.info(DOMAIN, TAG, 'Long running background task stopped')

    notificationManager.cancel(BG_TASK_ID).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `Cancel bg notification failed: ${err.message}`)
    })
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `stopBackgroundRunning failed: ${e.message}`)
  }
}

export function isBackgroundTaskRunning(): boolean {
  return state.isRunning
}
