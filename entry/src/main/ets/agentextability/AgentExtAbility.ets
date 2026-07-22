import { common, AgentExtensionAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { processUserInput } from '../service/AgentService';
import { ChatMessage, MessageRole, RiskLevel } from '../model/ChatModel';

const DOMAIN = 0xF000;
const TAG = 'DiTingAgent';

class A2ATask {
  id: string = ''
  status: string = 'working'
  content: string = ''
}

class A2AMessage {
  type: string = ''
  task: A2ATask = new A2ATask()
  artifact: A2AArtifact = new A2AArtifact()
}

class A2AArtifact {
  parts: A2APart[] = []
}

class A2APart {
  type: string = 'text'
  text: string = ''
}

export default class AgentExtAbility extends AgentExtensionAbility {
  private comProxy: common.AgentHostProxy | null = null;

  onCreate(want: Want): void {
    hilog.info(DOMAIN, TAG, 'DiTing Agent onCreate');
  }

  onConnect(want: Want, proxy: common.AgentHostProxy): void {
    hilog.info(DOMAIN, TAG, 'DiTing Agent onConnect');
    this.comProxy = proxy;
  }

  onAuth(proxy: common.AgentHostProxy, handshakeData: string): void {
    hilog.info(DOMAIN, TAG, 'DiTing Agent onAuth');
    try {
      proxy.authorize('auth_success');
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Auth failed: ${(err as Error).message}`);
    }
  }

  onData(proxy: common.AgentHostProxy, data: string): void {
    hilog.info(DOMAIN, TAG, `DiTing Agent onData: ${data.substring(0, 200)}`);

    let userText = '';
    try {
      const obj: Record<string, Object> = JSON.parse(data) as Record<string, Object>;
      userText = (obj['text'] ?? '') as string || (obj['content'] ?? '') as string || (obj['data'] ?? '') as string || data;
    } catch (e) {
      userText = data;
    }

    if (userText.trim().length === 0) {
      userText = '你好';
    }

    const urlPattern = new RegExp('https?:\\/\\/[^\\s<>"{}|\\\\^`[\\]]+');
    const urlMatch = userText.match(urlPattern);
    if (urlMatch) {
      const url = urlMatch[0];
      userText = `帮我检测这个链接的安全性：${url}`;
    }

    const newMessages = processUserInput(userText, []);
    const agentMsg = newMessages[newMessages.length - 1];

    if (agentMsg && agentMsg.role === MessageRole.AGENT) {
      const task = new A2ATask();
      task.id = 'ditie_' + Date.now().toString();
      task.status = 'completed';

      const part = new A2APart();
      part.type = 'text';
      part.text = agentMsg.content;

      const artifact = new A2AArtifact();
      artifact.parts = [part];

      const response = new A2AMessage();
      response.type = 'task_status_update_event';
      response.task = task;
      response.artifact = artifact;

      try {
        proxy.sendData(JSON.stringify(response));
        hilog.info(DOMAIN, TAG, 'DiTing Agent response sent');
      } catch (err) {
        hilog.error(DOMAIN, TAG, `SendData failed: ${(err as Error).message}`);
      }
    }
  }

  onDisconnect(want: Want, proxy: common.AgentHostProxy): void {
    hilog.info(DOMAIN, TAG, 'DiTing Agent onDisconnect');
    this.comProxy = null;
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'DiTing Agent onDestroy');
    this.comProxy = null;
  }
}
