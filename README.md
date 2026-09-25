# Muse / Hatch 运行环境快照

[English](README.en.md) · [中文分析报告](PROJECT_ANALYSIS.md) · [文件校验清单](SHA256SUMS)

这份仓库存档了一个 **Muse / Hatch 个人 AI Agent 环境的部分文件**，包括产品说明、技能定义、连接器权限清单、Linux 运行环境脚本，以及随包程序和依赖，供结构阅读与技术分析。

**它不是完整源码仓库，也不是可以一键部署的安装包。** 核心程序主要以 Linux x86-64 ELF 二进制提供；构建源码、完整宿主配置、rootfs 和部分运行资源不在这份快照中。仓库附带的材料自述使用 Muse、Hatch、Jarvis 等名称；本存档不代表官方发布或认可，也未独立验证这些材料的来源与产品声明。

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
