# Muse / Hatch Skills 与运行环境快照

[English](README.en.md) · [中文分析报告](PROJECT_ANALYSIS.md) · [文件校验清单](SHA256SUMS)

这份仓库存档了一个 **Muse / Hatch 个人 AI Agent 环境的部分文件**，包括产品说明、技能定义、连接器权限清单、Linux 运行环境脚本，以及随包程序和依赖，供结构阅读与技术分析。

**它不是完整源码仓库，也不是可以一键部署的安装包。** 核心程序主要以 Linux x86-64 ELF 二进制提供；构建源码、完整宿主配置、rootfs 和部分运行资源不在这份快照中。仓库附带的材料自述使用 Muse、Hatch、Jarvis 等名称；本存档不代表官方发布或认可，也未独立验证这些材料的来源与产品声明。

## Skills：本仓库的重点阅读内容

对研究 Agent 工作流设计而言，随包技能文本是这份快照中尤其值得阅读的部分：它们具体描述了 **何时触发、如何分流任务、使用哪些工具、怎样处理授权与失败，以及如何验收交付物**。阅读这些内容不需要下载体积较大的二进制。

目录里共有 **72 个 `SKILL.md` 路径：68 个独立技能文件，加上 4 个符号链接别名**。下面的分类表完整覆盖 68 个独立文件，别名单独列出。名称使用目录路径，可能与 frontmatter 中的名称不同。这里称为“随包技能”，表示它们在快照中的位置；尚未独立认证其官方来源，也不将其称为已验证的官方开源发布。

### 建议优先阅读

以下按工作流设计的参考价值选择，不代表运行效果排名，也不代表可以直接安装使用。

| 技能 | 值得研究的设计 |
|---|---|
| [wide-research](opt/hatch/skills/wide-research/SKILL.md) | 如何限定协调者与 worker、统一输出契约，并报告失败覆盖。 |
| [skill-creator](opt/hatch/skills/skill-creator/SKILL.md) | 如何让触发条件明确、主文件精简、参考资料按需加载。 |
| [artifacts/testing](opt/hatch/skills/artifacts/testing/SKILL.md) | 如何将“生成成功”与“交付物可用”分开验收。 |
| [goals](opt/hatch/skills/goals/SKILL.md) | 如何按领域区分首次建目标与后续跟进，避免重复 intake。 |
| [forget](opt/hatch/skills/forget/SKILL.md) | 如何处理副本、衍生状态与可能重新写回信息的后台任务。 |
| [travel-planning](opt/hatch/skills/travel-planning/SKILL.md) | 如何把行程研究与实时可订查询、交易分开路由。 |
| [magic-moment](opt/hatch/skills/magic-moment/SKILL.md) | 如何从事实素材、叙事、视觉到时间线与渲染前审阅组织流水线。 |
| [gmail](opt/hatch/skills/gmail/SKILL.md) | 如何结合技能正文、方法级权限 manifest 与行为评测场景阅读。 |

### Agent 工作流与记忆（6）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [wide-research](opt/hatch/skills/wide-research/SKILL.md) | 多输入并行研究；统一输出字段、覆盖率与失败项。 | — |
| [goals](opt/hatch/skills/goals/SKILL.md) | 分生活领域创建目标、记录承诺并持续跟进进展。 | [创建指南](opt/hatch/skills/goals/creation) · [跟进指南](opt/hatch/skills/goals/guides) |
| [skill-creator](opt/hatch/skills/skill-creator/SKILL.md) | 技能触发描述、目录拆分、工具/认证说明和编写检查。 | [参考](opt/hatch/skills/skill-creator/references) |
| [self-awareness](opt/hatch/skills/self-awareness/SKILL.md) | 根据实际文件和状态回答 Agent 能力、记忆与已完成工作。 | [参考](opt/hatch/skills/self-awareness/references) |
| [forget](opt/hatch/skills/forget/SKILL.md) | 规划、确认与验证跨记忆及衍生内容的遗忘流程。 | [参考](opt/hatch/skills/forget/references) |
| [muse_db](opt/hatch/skills/muse_db/SKILL.md) | 受限只读查询与跨表追踪，诊断执行和交付记录。 | [参考](opt/hatch/skills/muse_db/references) |

### 文档、表格与产物验收（6）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [artifacts/document](opt/hatch/skills/artifacts/document/SKILL.md) | Word 文档、模板、OOXML 编辑、修订与渲染验证。 | [参考](opt/hatch/skills/artifacts/document/references) |
| [artifacts/markdown](opt/hatch/skills/artifacts/markdown/SKILL.md) | Markdown 文档、README、纪要与交付前回读。 | — |
| [artifacts/pdf](opt/hatch/skills/artifacts/pdf/SKILL.md) | PDF 编排、现有文件处理、表单填写与几何校验。 | [参考](opt/hatch/skills/artifacts/pdf/references) |
| [artifacts/presentation](opt/hatch/skills/artifacts/presentation/SKILL.md) | 逐页 HTML、主题规划、幻灯片组装与 PPTX 导出。 | [参考](opt/hatch/skills/artifacts/presentation/references) |
| [artifacts/spreadsheet](opt/hatch/skills/artifacts/spreadsheet/SKILL.md) | 表格创建、清洗、公式重算与工作簿验证。 | [参考](opt/hatch/skills/artifacts/spreadsheet/references) |
| [artifacts/testing](opt/hatch/skills/artifacts/testing/SKILL.md) | 按产物类型检查、重新渲染、目视验收与占位符扫描。 | — |

### 旅行、本地搜索与预订（7）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [travel-planning](opt/hatch/skills/travel-planning/SKILL.md) | 行程规划、可行性、入境/转机与交通衔接。 | [评测场景](opt/hatch/skills/travel-planning/eval) · [参考](opt/hatch/skills/travel-planning/references) |
| [booking](opt/hatch/skills/booking/SKILL.md) | 航班、酒店、餐厅及门票的实时可订选项与交易入口。 | [评测场景](opt/hatch/skills/booking/eval) · [参考](opt/hatch/skills/booking/references) |
| [places-search](opt/hatch/skills/places-search/SKILL.md) | 按地点寻找和比较餐厅、咖啡馆、景点及本地服务。 | [评测场景](opt/hatch/skills/places-search/eval) |
| [duffel](opt/hatch/skills/duffel/SKILL.md) | 航班搜索、预订、付款、订单管理及明确请求的票价监测。 | [权限清单](opt/hatch/skills/duffel/manifest.yaml) · [评测场景](opt/hatch/skills/duffel/eval) |
| [flightaware](opt/hatch/skills/flightaware/SKILL.md) | 核实具体日期的航班时刻、延误、取消与运行变化。 | [权限清单](opt/hatch/skills/flightaware/manifest.yaml) · [评测场景](opt/hatch/skills/flightaware/eval) |
| [opentable](opt/hatch/skills/opentable/SKILL.md) | 餐厅可订时段查询，以及创建、修改和取消预订。 | [权限清单](opt/hatch/skills/opentable/manifest.yaml) · [评测场景](opt/hatch/skills/opentable/eval) |
| [ticketmaster](opt/hatch/skills/ticketmaster/SKILL.md) | 活动、座位和价格搜索，交付购票链接；不直接完成购买。 | [权限清单](opt/hatch/skills/ticketmaster/manifest.yaml) |

### 办公、邮箱与知识工具（16）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [gmail](opt/hatch/skills/gmail/SKILL.md) | 邮件检索、阅读、草稿、发送、回复、标签与退订。 | [权限清单](opt/hatch/skills/gmail/manifest.yaml) · [评测场景](opt/hatch/skills/gmail/eval) |
| [google-calendar](opt/hatch/skills/google-calendar/SKILL.md) | 议程、事件详情与日程变更。 | [权限清单](opt/hatch/skills/google-calendar/manifest.yaml) · [评测场景](opt/hatch/skills/google-calendar/eval) |
| [google-contacts](opt/hatch/skills/google-contacts/SKILL.md) | 搜索、创建、修改与删除联系人。 | [权限清单](opt/hatch/skills/google-contacts/manifest.yaml) · [评测场景](opt/hatch/skills/google-contacts/eval) |
| [google-docs](opt/hatch/skills/google-docs/SKILL.md) | 读取、创建与编辑 Google 文档。 | [权限清单](opt/hatch/skills/google-docs/manifest.yaml) |
| [google-drive](opt/hatch/skills/google-drive/SKILL.md) | 文件与文件夹管理、上传下载及分享。 | [权限清单](opt/hatch/skills/google-drive/manifest.yaml) · [评测场景](opt/hatch/skills/google-drive/eval) |
| [google-forms](opt/hatch/skills/google-forms/SKILL.md) | 读取、创建和更新表单，读取回复。 | [权限清单](opt/hatch/skills/google-forms/manifest.yaml) |
| [google-sheets](opt/hatch/skills/google-sheets/SKILL.md) | 读取、写入与管理 Google 表格。 | [权限清单](opt/hatch/skills/google-sheets/manifest.yaml) |
| [google-slides](opt/hatch/skills/google-slides/SKILL.md) | 读取、创建与编辑 Google 幻灯片。 | [权限清单](opt/hatch/skills/google-slides/manifest.yaml) |
| [google-tasks](opt/hatch/skills/google-tasks/SKILL.md) | 任务列表、任务创建、修改与完成。 | [权限清单](opt/hatch/skills/google-tasks/manifest.yaml) · [评测场景](opt/hatch/skills/google-tasks/eval) |
| [outlook-calendar](opt/hatch/skills/outlook-calendar/SKILL.md) | 读取、创建、修改与删除 Outlook 日程。 | [权限清单](opt/hatch/skills/outlook-calendar/manifest.yaml) |
| [outlook-contacts](opt/hatch/skills/outlook-contacts/SKILL.md) | 读取、搜索及管理 Outlook 联系人。 | [权限清单](opt/hatch/skills/outlook-contacts/manifest.yaml) |
| [outlook-mail](opt/hatch/skills/outlook-mail/SKILL.md) | 读取、搜索、发送、回复与删除 Outlook 邮件。 | [权限清单](opt/hatch/skills/outlook-mail/manifest.yaml) |
| [notion](opt/hatch/skills/notion/SKILL.md) | 通过 Notion MCP 搜索、读取、创建与更新页面。 | [权限清单](opt/hatch/skills/notion/manifest.yaml) |
| [granola](opt/hatch/skills/granola/SKILL.md) | 通过 OAuth MCP 搜索和读取会议笔记与转录。 | [权限清单](opt/hatch/skills/granola/manifest.yaml) |
| [muse-mail](opt/hatch/skills/muse-mail/SKILL.md) | Muse Mail 专用邮箱、转发邮件及收件处理流程。 | [参考](opt/hatch/skills/muse-mail/references) |
| [calendly](opt/hatch/skills/calendly/SKILL.md) | 读取 Calendly 事件、事件类型并管理预约数据。 | [权限清单](opt/hatch/skills/calendly/manifest.yaml) |

### 社交网络与消息（6）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [facebook-cli](opt/hatch/skills/facebook-cli/SKILL.md) | 读取 Facebook 内容与关系，管理自己的 Marketplace 刊登。 | [权限清单](opt/hatch/skills/facebook-cli/manifest.yaml) · [参考](opt/hatch/skills/facebook-cli/references) |
| [instagram](opt/hatch/skills/instagram/SKILL.md) | 读取内容、账号信息与洞察，按请求发布帖子或视频。 | [权限清单](opt/hatch/skills/instagram/manifest.yaml) · [参考](opt/hatch/skills/instagram/references) |
| [instagram-messages](opt/hatch/skills/instagram-messages/SKILL.md) | 收件箱、会话、私信搜索与发送。 | [权限清单](opt/hatch/skills/instagram-messages/manifest.yaml) |
| [messenger](opt/hatch/skills/messenger/SKILL.md) | 联系人、通话及会话检索，发送、编辑、撤回和反应。 | [权限清单](opt/hatch/skills/messenger/manifest.yaml) |
| [threads](opt/hatch/skills/threads/SKILL.md) | 账号、帖子、信息流与洞察；搜索及按请求发布。 | [权限清单](opt/hatch/skills/threads/manifest.yaml) |
| [threads-messages](opt/hatch/skills/threads-messages/SKILL.md) | 读取 Threads 消息收件箱、会话及发送消息。 | [权限清单](opt/hatch/skills/threads-messages/manifest.yaml) |

### 购物、商品与金融数据（3）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [shopping](opt/hatch/skills/shopping/SKILL.md) | 商品搜索、图片搜商品、比价、展示与购买流程路由。 | [参考](opt/hatch/skills/shopping/references) |
| [printify](opt/hatch/skills/printify/SKILL.md) | 商品目录、店铺、商品与订单管理。 | [权限清单](opt/hatch/skills/printify/manifest.yaml) |
| [plaid](opt/hatch/skills/plaid/SKILL.md) | 读取已连接金融账户、余额、交易、负债与投资数据。 | [权限清单](opt/hatch/skills/plaid/manifest.yaml) · [评测场景](opt/hatch/skills/plaid/eval) |

### 健康与健身数据（6）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [apple-healthkit](opt/hatch/skills/apple-healthkit/SKILL.md) | 读取同步的 Apple Health 指标、睡眠与运动记录。 | [权限清单](opt/hatch/skills/apple-healthkit/manifest.yaml) |
| [google-health-connect](opt/hatch/skills/google-health-connect/SKILL.md) | 读取 Android 同步的健康指标、睡眠与运动记录。 | [权限清单](opt/hatch/skills/google-health-connect/manifest.yaml) |
| [function-health](opt/hatch/skills/function-health/SKILL.md) | 读取检验指标及临床备注。 | [权限清单](opt/hatch/skills/function-health/manifest.yaml) |
| [healthex](opt/hatch/skills/healthex/SKILL.md) | 连接 HealthEx 并查询药物、化验及健康记录。 | [权限清单](opt/hatch/skills/healthex/manifest.yaml) |
| [peloton](opt/hatch/skills/peloton/SKILL.md) | 健身课程浏览、课程表及训练预约。 | [权限清单](opt/hatch/skills/peloton/manifest.yaml) |
| [withings](opt/hatch/skills/withings/SKILL.md) | 连接设备服务并读取身体、活动、睡眠和心脏相关数据。 | [权限清单](opt/hatch/skills/withings/manifest.yaml) · [参考](opt/hatch/skills/withings/references) |

### 图像、音频与视频工作流（8）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [image-search](opt/hatch/skills/image-search/SKILL.md) | 按文本搜索图片及其来源页面。 | — |
| [media-library](opt/hatch/skills/media-library/SKILL.md) | 搜索、查看用户图库及已连接设备相册。 | — |
| [spotify](opt/hatch/skills/spotify/SKILL.md) | 搜索音乐与播客、管理播放列表及相关内容。 | [权限清单](opt/hatch/skills/spotify/manifest.yaml) |
| [generate_podcast](opt/hatch/skills/generate_podcast/SKILL.md) | 创作单人或多人播客、简报与口播摘要，交付 MP3。 | [参考](opt/hatch/skills/generate_podcast/references) |
| [tts](opt/hatch/skills/tts/SKILL.md) | 将给定文本转换为单人或多人语音。 | [权限清单](opt/hatch/skills/tts/manifest.yaml) |
| [voice-design](opt/hatch/skills/voice-design/SKILL.md) | 选择或设计用户请求的新语音。 | — |
| [voice-selector](opt/hatch/skills/voice-selector/SKILL.md) | 系统静态语音目录；本身不是面向用户的工作流。 | — |
| [magic-moment](opt/hatch/skills/magic-moment/SKILL.md) | 将真人口播与真实 Agent 工作成果同步编排为竖屏视频。 | [流程指南](opt/hatch/skills/magic-moment/guide) · [设计参考](opt/hatch/skills/magic-moment/reference) |

### 设备、通信与网络（6）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [device-data](opt/hatch/skills/device-data/SKILL.md) | 读取缓存联系人与日历，清除 Muse 本地副本。 | — |
| [wearable-device-skills](opt/hatch/skills/wearable-device-skills/SKILL.md) | 发现、检查和调用配对手机或穿戴设备动态提供的能力。 | — |
| [wearables-comms](opt/hatch/skills/wearables-comms/SKILL.md) | 从请求来源穿戴设备发起通话/短信，处理联系人与号码歧义。 | — |
| [philips-hue](opt/hatch/skills/philips-hue/SKILL.md) | 控制智能灯、房间、场景与设备。 | [权限清单](opt/hatch/skills/philips-hue/manifest.yaml) |
| [tessie](opt/hatch/skills/tessie/SKILL.md) | 读取 Tesla 状态并调用明确的车辆操作接口。 | [权限清单](opt/hatch/skills/tessie/manifest.yaml) |
| [tailscale](opt/hatch/skills/tailscale/SKILL.md) | 加入 Tailnet/Headscale、检查连接并经 TCP 代理访问私有机器。 | — |

### Muse 产品操作（4）

| 技能 | 文档描述的用途 | 配套资料 |
|---|---|---|
| [muse-early-access](opt/hatch/skills/muse-early-access/SKILL.md) | 申请、查询或撤回抢先体验请求。 | — |
| [muse-feedback](opt/hatch/skills/muse-feedback/SKILL.md) | 按用户授权提交、查看或撤回反馈与功能请求。 | — |
| [share-ideas](opt/hatch/skills/share-ideas/SKILL.md) | 按明确请求发布可复用的原生 Muse Idea。 | — |
| [subscription-status](opt/hatch/skills/subscription-status/SKILL.md) | 读取套餐、额度、用量、重置时间与计费相关状态。 | — |

### 别名与额外资源

| 别名入口 | 实际指向 |
|---|---|
| [facebook](opt/hatch/skills/facebook/SKILL.md) | [facebook-cli](opt/hatch/skills/facebook-cli/SKILL.md) |
| [meta-threads](opt/hatch/skills/meta-threads/SKILL.md) | [threads](opt/hatch/skills/threads/SKILL.md) |
| [podcast](opt/hatch/skills/podcast/SKILL.md) | [generate_podcast](opt/hatch/skills/generate_podcast/SKILL.md) |
| [voice-calls](opt/hatch/skills/voice-calls/SKILL.md) | [voice-selector](opt/hatch/skills/voice-selector/SKILL.md) |

`voice-calls` 实际指向静态语音目录，不能根据名字推断它提供 Agent 代打电话能力。[Spaces 目录](opt/hatch/skills/spaces) 含运行时文档与模板，但没有顶层 `SKILL.md`，因此不额外计为一个技能。[Artifacts 共享参考](opt/hatch/skills/artifacts/references) 包含图表、地图、实时数据、Markdown 等输出说明。全目录另有 40 个 manifest 路径和 12 份 eval YAML；这些是配套文件数，不是额外技能数，也不代表评测已经通过。

### 如何阅读与迁移

- 先看技能的触发条件、边界与输出契约，再结合它引用的参考文档及权限 manifest 阅读。
- 工作流模式可以用于改进自己的 Agent 指令，但需要按目标环境调整工具名、工作区路径、授权规则和验收步骤。
- 连接器技能依赖对应 CLI/MCP、账户连接、OAuth scopes 和运行时授权。复制 Markdown 不会自动获得这些能力。
- 部分引用的辅助程序并未包含：Artifacts 验证脚本、skill-creator 的连接器脚手架，以及 Magic Moment 的 `mm` 可执行程序均缺失；Spaces 也缺少 SDK/构建资源。技能文档可阅读，执行链路并不完整。
- 保留来源归属和适用许可。“存档中可见”不等于“官方来源已认证、可独立运行或可任意重新授权”。

只想研究这些技能，可以跳过全部 LFS 二进制下载：

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/win4r/muse-file.git
cd muse-file
```

打开 `opt/hatch/skills/` 或点击上方目录即可，无需执行随包程序。

## 从哪里开始

- 想快速理解系统：阅读 [项目分析报告](PROJECT_ANALYSIS.md)，包含架构图、能力边界、交付缺项和证据索引。
- 想了解产品设计：从 [产品概览](home/hatch/docs/muse.md)、[目标](home/hatch/docs/goals.md)、[后台调度](home/hatch/docs/scheduling-and-watching.md) 和 [后台整理](home/hatch/docs/self_improvement.md) 开始。
- 想研究工具与权限：阅读 [连接器说明](home/hatch/docs/connectors.md)、[Gmail 技能](opt/hatch/skills/gmail/SKILL.md) 和 [权限 manifest](opt/hatch/skills/gmail/manifest.yaml)。
- 想研究运行架构：阅读 [runtime-cell 启动脚本](opt/hatch/runtime-cell/launch-daemon.sh)、[daemon 控制脚本](opt/hatch/runtime-cell/control-daemon.sh) 和 [数据库关系文档](opt/hatch/skills/muse_db/references/schema.md)。
- 想研究生成式应用：阅读 [Artifacts 说明](home/hatch/docs/artifacts.md) 与 [TypeScript Web Artifact Runtime](opt/hatch/skills/spaces/ts-runtime/README.md)，注意两者的发布能力描述存在差异。

## 目录结构

```text
.
├── README.md                    # 中文入口
├── README.en.md                 # English overview
├── PROJECT_ANALYSIS.md          # 中文技术分析报告
├── SHA256SUMS                   # 普通文件的 SHA-256 校验值
├── .gitattributes               # 二进制文件的 Git LFS 跟踪规则
├── .gitignore                  # 本机元数据排除规则
├── home/hatch/
│   ├── config/                  # 本地配置声明
│   ├── docs/                    # 产品、渠道、设备与能力说明
│   ├── assets/                  # 此快照包含的资源文档
│   ├── PROACTIVE_PREFERENCES.md
│   └── workspace/               # 随快照保留的历史审查材料
└── opt/
    ├── hatch/
    │   ├── bin/                 # 核心程序与连接器 CLI
    │   ├── runtime-cell/        # Linux 环境生命周期脚本
    │   └── skills/              # 技能、权限 manifest、参考文档与评测场景
    └── hatch-image/bin/         # Bun、Codex、npm、RTC 及相关资源
```

初始材料盘点（排除 `.DS_Store`，不含新增仓库文档与校验清单）：

| 项目 | 数量 |
|---|---:|
| 原始快照文件路径 | 2,652 |
| 产品与设备文档 | 26 |
| 技能顶层目录 / `SKILL.md` | 68 / 72 |
| `manifest.yaml` | 40 |
| eval YAML 场景文件 | 12 |
| `opt/hatch/bin` 目录项 | 77 |
| schema 文档中的命名空间 / 关系条目 | 17 / 195 |

精确的发布文件集合以 Git 树和 `SHA256SUMS` 为准。数据库数字是文档统计，不是实际数据库查询结果。

## 系统设计概要

材料呈现的工作流是：用户提出任务，Agent 读取个人上下文，结合目标与记忆调用工具，将结果交付为消息、文档或应用，再由后台流程维护记忆、关系和建议。

| 层次 | 可见材料 |
|---|---|
| 产品与个人上下文 | Goals、Feed、Ideas、Memory、Relationships |
| Agent 执行 | Hatch daemon、执行服务、连接器 CLI、浏览器与设备工具 |
| 能力契约 | `SKILL.md` 和方法级权限、OAuth scopes 等 manifest |
| 持久化与追踪 | PostgreSQL schema 文档、运行与投递记录设计 |
| 运行隔离 | systemd-nspawn、宿主/客体生命周期、代理与信任配置 |
| 生成应用 | Artifacts、Spaces、TypeScript SDK 和数据库迁移的说明文档 |

这些文件可以说明设计意图和部分实现形态，不能证明相应功能在线可用、账户已连接、权限已授予或测试已经通过。

## 下载与完整性校验

### 完整下载（包括二进制）

先安装 [Git LFS](https://git-lfs.com/)，然后执行：

```bash
git lfs install
git clone https://github.com/win4r/muse-file.git
cd muse-file
git lfs pull
git lfs fsck
```

二进制与共享库由 Git LFS 管理。未安装 LFS 或跳过下载时，相关路径可能只有小型指针文件。普通 ZIP 下载不能作为完整 LFS 内容已获取的证明；优先使用以上方式。

原始文件逐路径累计约 2.02 GB；按本地 inode 去重约 1.55 GB。Git 不保留硬链接关系，因此 checkout 后共享镜像的多个名字通常成为独立文件，需要按约 2 GB 工作区加 Git/LFS 缓存预留空间。

### 只阅读文档和脚本

```bash
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/win4r/muse-file.git
cd muse-file
```

需要二进制时再运行 `git lfs pull`。

### 验证文件内容

完成 LFS 下载后，在仓库根目录运行：

```bash
# Linux
sha256sum --check SHA256SUMS

# macOS
shasum -a 256 --check SHA256SUMS
```

清单覆盖发布时的普通文件，不包含清单自身、`.git` 和被忽略的本机元数据。符号链接由 Git 跟踪，不列入该普通文件清单。哈希用于检查内容一致性，不验证原始来源或程序安全性。

## 可运行性与已知缺项

当前快照无法独立启动。不要将 README 中的下载步骤理解为安装或部署步骤。

- 核心程序面向 **Linux x86-64**，不能在 macOS 原生运行。
- 缺少核心源码与完整构建定义，无法重建 daemon 和连接器。
- 缺少完整宿主服务、rootfs、数据库迁移和控制面依赖。
- Web Artifact README 引用的 `build.mjs`、`sdk/` 和 `dist/space-sdk.tgz` 不在快照中。
- 评测 YAML 引用的 `spawn-eval-instructions.md` 不在快照中。
- `runtime-cell.kdl` 引用的 `run-execd.sh` 不在快照中；不排除完整镜像另行生成该文件。
- `opt/hatch-image/bin/gws` 是零字节文件；这不代表其他 Google CLI 入口也失效。
- 产品文档限制为静态产物发布，技术文档则描述带数据库的 Cloudflare 导出；适用版本与开放渠道未确认。

随包脚本中含绝对路径、挂载、权限和系统服务操作，它们为原始 Linux 环境编写，不是面向任意电脑的通用安装脚本。

## 验证范围

本地分析已完成文件与硬链接盘点、关键程序格式检查、文档交叉阅读，并对 15 个 runtime-cell `.sh` 文件执行 `sh -n`，全部通过语法检查。

未进行服务启动、核心源码编译、数据库连通、真实连接器调用、设备接入、完整应用构建或动态安全验证。历史 [安全审查材料](home/hatch/workspace/muse-security-audit.md) 保留了其原文与原始范围，不构成对整个系统的安全背书。

## 版权与许可

这是一份公开存档，**公开可见不等于所有内容获得统一的开源授权**。未为整份快照添加 MIT、Apache 等总许可；原始组件的版权、商标及各自已有的许可保持不变。随包 npm 及依赖的许可证保留在对应目录，例如 [npm LICENSE](opt/hatch-image/bin/npm-package/LICENSE)。

这份快照未提供可确认覆盖全部 Muse/Hatch 内容的统一再分发许可证。本仓库不替原权利人授予额外使用、修改或再分发权利；使用者应按具体文件及组件确认适用条款。
