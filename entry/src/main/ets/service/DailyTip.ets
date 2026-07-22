import { notificationManager } from '@kit.NotificationKit'
import { preferences } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'

const DOMAIN = 0xF000
const TAG = 'DiTingTip'
const PREF_NAME = 'diting_daily_tip'
const KEY_TIP_INDEX = 'tip_index'
const KEY_LAST_TIP_DATE = 'last_tip_date'
const NOTIFICATION_ID = 20001

const TIPS: string[] = [
  '收到"账号异常"短信？先别点链接！直接打开官方App或拨打官方客服核实。',
  '公共Wi-Fi上不要登录银行或支付账户，使用移动数据更安全。',
  '每个账户用不同密码，密码管理器是你的好帮手。',
  'App要位置权限但不需要定位？拒绝它！最小权限原则保护隐私。',
  '定期检查手机已安装App权限，删除不再使用的应用。',
  '开启双重认证（2FA），即使密码泄露也能保护账户。',
  '不要扫描来路不明的二维码，可能导向钓鱼网站。',
  '旧手机卖掉或送人前，务必恢复出厂设置并退出所有账号。',
  '收到"中奖""免费领"信息？天上不会掉馅饼，99%是诈骗。',
  '定期更新手机系统和App，安全补丁能堵住已知漏洞。',
  '不要在充电桩上选择"信任此设备"，防止数据被读取。',
  '社交平台不要暴露真实住址、行程等隐私信息。',
  '浏览器提示"证书不可信"？立即关闭，不要继续访问。',
  '下载App只去官方应用商店，第三方来源风险极高。',
  '蓝牙不用时就关掉，减少被攻击面。',
  '重置广告标识符，让追踪者无法持续跟踪你。',
  '邮箱收到含附件的陌生邮件？不要打开，可能是恶意软件。',
  '设置屏幕锁定（密码/指纹/面容），手机丢失也能保护数据。',
  '备份重要数据！勒索软件不可怕，有备份就不怕。',
  '看到"限时优惠""仅剩1个"的网页？冷静，很可能是钓鱼套路。',
  '视频通话中有人要求转账？先挂断，用电话回拨确认身份。',
  '不要将身份证照片存在手机相册，如需要请加密保存。',
  '购物App索取通讯录权限？不需要，拒绝它。',
  '陌生人发来的文件不要直接打开，先让安全软件扫描。',
  '多个账户不要用同一密码，一个泄露全部遭殃。',
  '安装App时仔细阅读权限请求，不给不需要的权限。',
  '连接公共Wi-Fi后，先打开谛听检查网络安全！',
  '手机突然异常发热耗电？可能有恶意软件在后台运行。',
  '不要点击短信中的短链接，先用谛听检测安全性。',
  '定期清理手机中不再使用的App，减少权限暴露面。'
]

class TipState {
  pref: preferences.Preferences | null = null
  tipIndex: number = 0
}

const state = new TipState()

export async function initDailyTip(context: common.UIAbilityContext): Promise<void> {
  try {
    state.pref = await preferences.getPreferences(context, PREF_NAME)
    state.tipIndex = await state.pref.get(KEY_TIP_INDEX, 0) as number
    hilog.info(DOMAIN, TAG, `Daily tip init, index: ${state.tipIndex}`)
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `initDailyTip failed: ${e.message}`)
  }
}

export async function shouldShowDailyTip(): Promise<boolean> {
  if (!state.pref) {
    return false
  }
  try {
    const today = new Date().toDateString()
    const lastDate = await state.pref.get(KEY_LAST_TIP_DATE, '') as string
    return lastDate !== today
  } catch (_err) {
    return false
  }
}

export async function markDailyTipShown(): Promise<void> {
  if (!state.pref) {
    return
  }
  try {
    const today = new Date().toDateString()
    await state.pref.put(KEY_TIP_INDEX, state.tipIndex)
    await state.pref.put(KEY_LAST_TIP_DATE, today)
    await state.pref.flush()
  } catch (_err) {
    // ignore
  }
}

export function getDailyTipContent(): string {
  const tip = TIPS[state.tipIndex % TIPS.length]
  state.tipIndex = (state.tipIndex + 1) % TIPS.length
  return tip
}

export async function checkAndSendDailyTip(): Promise<void> {
  if (!state.pref) {
    return
  }

  try {
    const today = new Date().toDateString()
    const lastDate = await state.pref.get(KEY_LAST_TIP_DATE, '') as string
    if (lastDate === today) {
      return
    }

    const tip = getDailyTipContent()

    await state.pref.put(KEY_TIP_INDEX, state.tipIndex)
    await state.pref.put(KEY_LAST_TIP_DATE, today)
    await state.pref.flush()

    const req: notificationManager.NotificationRequest = {
      id: NOTIFICATION_ID,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: '🛡️ 谛听·今日安全小贴士',
          text: tip
        }
      } as notificationManager.NotificationContent
    }
    await notificationManager.publish(req)
    hilog.info(DOMAIN, TAG, `Daily tip sent: ${tip.substring(0, 30)}`)
  } catch (err) {
    const e = err as Error
    hilog.error(DOMAIN, TAG, `checkAndSendDailyTip failed: ${e.message}`)
  }
}

export function getCurrentTip(): string {
  const idx = state.tipIndex > 0 ? (state.tipIndex - 1 + TIPS.length) % TIPS.length : 0
  return TIPS[idx]
}
