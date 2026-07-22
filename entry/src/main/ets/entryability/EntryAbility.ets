import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { startLongRunningTask, stopLongRunningTask } from '../service/BackgroundTaskService';
import { initHistoryStore } from '../service/SecurityHistory';
import { initDailyTip } from '../service/DailyTip';

const DOMAIN = 0xF000;
const TAG = 'DiTingEntry';

class AppStorageKeys {
  static readonly INCOMING_URL: string = 'incoming_url'
  static readonly INCOMING_TEXT: string = 'incoming_text'
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, '%{public}s', 'DiTing Agent onCreate');

    initHistoryStore(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `History init failed: ${err.message}`);
    });

    initDailyTip(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `Daily tip init failed: ${err.message}`);
    });

    this.processIncomingWant(want);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'DiTing Agent onDestroy');
    stopLongRunningTask(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `Stop bg task failed: ${err.message}`);
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
    startLongRunningTask(this.context).catch((err: Error) => {
      hilog.error(DOMAIN, TAG, `Start bg task failed: ${err.message}`);
    });
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'DiTing Agent onNewWant');
    this.processIncomingWant(want);
  }

  private processIncomingWant(want: Want): void {
    if (want.uri && want.uri.length > 0) {
      const uri = want.uri
      if (uri.indexOf('http://') === 0 || uri.indexOf('https://') === 0) {
        AppStorage.setOrCreate(AppStorageKeys.INCOMING_URL, uri)
        hilog.info(DOMAIN, TAG, `Incoming URI: ${uri.substring(0, 50)}`)
        return
      }
      const ditingPrefix = 'diting://'
      if (uri.indexOf(ditingPrefix) === 0) {
        const payload = uri.substring(ditingPrefix.length)
        if (payload.indexOf('http://') === 0 || payload.indexOf('https://') === 0) {
          AppStorage.setOrCreate(AppStorageKeys.INCOMING_URL, payload)
          hilog.info(DOMAIN, TAG, `Incoming diting URL: ${payload.substring(0, 50)}`)
          return
        }
        AppStorage.setOrCreate(AppStorageKeys.INCOMING_TEXT, payload)
        hilog.info(DOMAIN, TAG, `Incoming diting text: ${payload.substring(0, 50)}`)
        return
      }
    }

    if (!want.parameters) {
      return
    }

    const url = want.parameters['url'] as string
    if (url && url.length > 0) {
      AppStorage.setOrCreate(AppStorageKeys.INCOMING_URL, url)
      hilog.info(DOMAIN, TAG, `Incoming URL: ${url.substring(0, 50)}`)
      return
    }

    const text = want.parameters['text'] as string
    if (text && text.length > 0) {
      AppStorage.setOrCreate(AppStorageKeys.INCOMING_TEXT, text)
      hilog.info(DOMAIN, TAG, `Incoming text: ${text.substring(0, 50)}`)
    }
  }
}
