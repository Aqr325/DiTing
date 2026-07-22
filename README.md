# 谛听 · DiTing

**端侧 AI 安全守护 Agent** — 24/7 On-Device Security Guardian for HarmonyOS

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-6.1.1-blue)](https://developer.huawei.com) [![API](https://img.shields.io/badge/API-24-green)](https://developer.huawei.com) [![License](https://img.shields.io/badge/License-Apache--2.0-orange)](LICENSE)

---

## 简介

谛听是一款运行在 HarmonyOS 设备端的 **7×24 小时主动安全守护应用**。所有分析推理均在设备本地完成，用户数据不上传云端，隐私零泄露。

> 谛听，取自地藏菩萨坐骑"谛听"——能辨万物真伪、善听世间一切。

### 核心理念

| 原则 | 说明 |
|------|------|
| **端侧优先** | 所有推理在设备端进行，用户数据不上传 |
| **主动守护** | 自动推送安全事件警报，无需手动检查 |
| **零门槛** | 专业术语通俗化，提供可操作建议 |
| **用户决定** | 建议但不自动删除/卸载，最终决定权在用户 |

---

## 功能概览

### 🔍 8 大安全检测工具

| 工具 | 触发方式 | 说明 |
|------|----------|------|
| 🔗 链接安全检测 | 直接发送链接 | 分析 SSL/TLS、钓鱼特征、域名可疑度 |
| 🔐 应用权限分析 | "检查XX应用权限" | 分析应用权限数量、风险权限识别 |
| 📁 文件安全扫描 | "扫描文件 xxx" | 检测文件威胁、可疑特征 |
| 🌐 网络安全监控 | "检查网络" | 检测网络连接安全、代理、VPN 状态 |
| 📶 Wi-Fi 安全检测 | "检查Wi-Fi安全" | 分析加密方式、信号异常、隐藏 SSID |
| 🛡️ 隐私健康评分 | "全面检查" | 5 维度隐私健康体检与综合评分 |
| 📋 安全报告生成 | "生成安全报告" | 输出完整安全评估报告 |
| 📱 设备安全状态 | "设备安全" | 聚合 6 大守护模块实时状态 |

### 🛡️ 6 大实时守护

| 守护模块 | 监控内容 | 告警触发 |
|----------|----------|----------|
| 📋 剪贴板守护 | 剪贴板中的可疑链接 | 检测到 URL 自动分析 |
| 🌐 网络守护 | 网络连接变化 | 切换到不安全网络时告警 |
| 📲 应用安装守护 | 新应用安装/替换 | 安装高风险应用时告警 |
| 🔋 电池/USB 守护 | 充电状态与温度 | 异常耗电或过温时告警 |
| 📡 蓝牙守护 | 蓝牙配对状态 | 未知设备配对时告警 |
| 📶 SIM 卡守护 | SIM 卡状态变化 | SIM 卡热拔插时告警 |

### 📚 安全知识库

覆盖 20+ 安全话题，用通俗语言解释专业概念：

钓鱼攻击 · 恶意软件 · 勒索软件 · 密码安全 · 双重认证(2FA) · VPN · 蓝牙安全 · 隐私保护 · 社工攻击 · SSL/TLS · XSS · 中间人攻击 · Root/越狱风险 · 漏洞与补丁 · 数据泄露 · 二维码安全 · 公共 Wi-Fi · 应用安全 · 数据备份 · AI 安全 · 深度伪造 · 物联网安全 · 加密货币安全 · 键盘记录/间谍软件

---

## 风险级别体系

| 级别 | 标识 | 含义 |
|------|------|------|
| 🟢 安全 | SAFE | 未发现安全风险 |
| 🟡 可疑 | SUSPICIOUS | 存在潜在风险，建议关注 |
| 🔴 危险 | DANGEROUS | 发现明确风险，建议处理 |
| ⛔ 紧急 | CRITICAL | 严重安全威胁，需立即处理 |

---

## 项目结构

```
DiTing/
├── AppScope/                          # 应用全局配置
├── entry/
│   └── src/main/
│       ├── ets/
│       │   ├── agentextability/       # 小艺智能体扩展
│       │   │   └── AgentExtAbility.ets
│       │   ├── common/
│       │   │   └── AppConstants.ets   # 全局常量 & 安全评分算法
│       │   ├── components/
│       │   │   ├── MessageBubble.ets  # 聊天气泡（富文本渲染）
│       │   │   ├── OnboardingGuide.ets# 引导页
│       │   │   ├── QuickActionPanel.ets# 快捷操作面板
│       │   │   └── SecurityDashboard.ets# 安全仪表盘
│       │   ├── entryability/
│       │   │   └── EntryAbility.ets   # 主入口 Ability
│       │   ├── model/
│       │   │   └── ChatModel.ets      # 数据模型
│       │   ├── pages/
│       │   │   ├── Index.ets          # 主页面（聊天+仪表盘）
│       │   │   ├── SecurityHistory.ets# 安全记录页
│       │   │   └── Settings.ets       # 设置页
│       │   └── service/
│       │       ├── AgentService.ets   # Agent 路由 & 格式化
│       │       ├── AppLifecycleMonitor.ets
│       │       ├── BackgroundTaskService.ets
│       │       ├── BatteryUsbMonitor.ets
│       │       ├── BluetoothMonitor.ets
│       │       ├── ClipboardMonitor.ets
│       │       ├── DailyTip.ets
│       │       ├── HapticService.ets
│       │       ├── MonitorOrchestrator.ets # 守护协调器
│       │       ├── NetworkWatch.ets
│       │       ├── NotificationService.ets
│       │       ├── SecurityHistory.ets
│       │       ├── SecurityReport.ets
│       │       ├── ShareService.ets
│       │       ├── SimChangeMonitor.ets
│       │       ├── ToolService.ets    # 8 大安全工具引擎
│       │       ├── UrlUtils.ets
│       │       └── WifiSecurity.ets
│       ├── module.json5               # 模块配置 & 权限声明
│       └── resources/
│           ├── base/                   # 浅色主题资源
│           │   ├── element/
│           │   │   ├── color.json     # 49 个设计 Token
│           │   │   ├── float.json
│           │   │   └── string.json
│           │   └── profile/
│           └── dark/                   # 暗色主题资源
│               └── element/
│                   └── color.json     # 暗色模式完整适配
├── build-profile.json5
└── oh-package.json5
```

---

## 技术特性

### 设计体系

- **8pt 间距体系**：2 / 4 / 8 / 12 / 16 / 20 px 层级化间距
- **49 个设计 Token**：颜色、阴影、边框统一管理，浅色/暗色双主题
- **iOS 风格聊天气泡**：左对齐 Agent / 右对齐 User，风险色左边条
- **富文本 AI 输出渲染**：`##` 标题 / `###` 小标题 / `•` 列表 / `---` 分隔线 / `>` 引用块
- **宽屏适配**：最大宽度 860px 居中，适配 phone / tablet / 2in1

### 安全评分算法

统一评分函数 `calcSecurityScore()`，综合考虑：

- 基础分 100
- 危险记录扣分（dangerous × 3 + suspicious）
- Wi-Fi 安全状态加/扣分
- 守护模块活跃加分
- 评分区间映射：🟢 ≥ 80 / 🟡 ≥ 60 / 🔴 ≥ 40 / ⛔ < 40

### 性能优化

- **I/O 防抖**：安全记录写入 2 秒防抖，避免频繁序列化
- **通知 Slot 串行化**：Promise 链防止重复创建通知通道
- **定时器生命周期管理**：aboutToDisappear 清理所有 interval/timeout
- **守护协调器**：MonitorOrchestrator 单例统一管理 6 大监控

---

## 开发环境

| 依赖 | 版本 |
|------|------|
| DevEco Studio | 5.0+ |
| HarmonyOS SDK | 6.1.1 (API 24) |
| ArkTS | 严格模式 |

### 构建与运行

1. 使用 DevEco Studio 打开项目
2. 配置签名（构建签名版需在 `build-profile.json5` 中配置 signingConfigs）
3. 连接 HarmonyOS 设备或启动模拟器
4. 点击 Run 运行

```bash
# 命令行构建
hvigorw --mode module -p module=entry@default -p product=default assembleHap
```

---

## 权限说明

| 权限 | 用途 | 类型 |
|------|------|------|
| `READ_PASTEBOARD` | 读取剪贴板检测可疑链接 | 用户授权 |
| `APPROXIMATELY_LOCATION` | Wi-Fi 扫描需要位置信息 | 用户授权 |
| `ACCESS_BLUETOOTH` | 蓝牙设备监控 | 用户授权 |
| `GET_WIFI_INFO` | 获取 Wi-Fi 连接信息 | 系统授权 |
| `GET_NETWORK_INFO` | 获取网络状态 | 系统授权 |
| `KEEP_BACKGROUND_RUNNING` | 后台持续守护 | 系统授权 |

---

## 版本历史

### v1.3.0

- 8 大安全检测工具 + 6 大实时守护
- 完整 UI：聊天界面 / 安全仪表盘 / 安全记录 / 设置 / 引导页
- 暗色模式全量适配（49 个设计 Token）
- 富文本 AI 输出渲染
- 小艺智能体扩展（AgentExtAbility）
- 全面代码审计：安全评分统一 / 误报消除 / I/O 防抖 / 竞态修复 / 暗色补全

---

## License

Apache License 2.0
