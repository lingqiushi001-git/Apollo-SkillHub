<div align="center">
  <img src="AppIcon.iconset/icon_256x256.png" width="128" height="128" alt="Apollo AgentHub Icon" />
  <h1>Apollo AgentHub</h1>
  <p><strong>Native macOS AI Agent Capability Hub & Research Radar for Antigravity, Codex & Claude Code</strong></p>
  <p>原生 macOS 跨端 AI 能力资产中枢 · 本地三资产热同步（Skills / MCP / Plugins）+ 外部研究雷达（关注收藏）</p>
  <p><sub>原名 Apollo SkillHub，自 v1.3.0 起正式升级为 <strong>Apollo AgentHub</strong>，与 <strong>Apollo AgentMeter</strong> 组成 Apollo Agent 原生工具套件。</sub></p>
</div>

---

## ✨ 核心特性 (Features)

### 1. 双层空间架构（v1.3.0 重磅升级）
- **本地运行态三资产**：顶栏分段控制纯粹聚焦本机已管理的三大能力载体——**`Skills 技能` · `MCP 服务` · `Plugins 插件`**。
- **独立「★ 关注收藏」研究雷达**：顶栏右侧以竖线独立区隔的琥珀金空间，专门用于收录只研究、只关注、暂不下载到本地的 **Skill / Plugin / MCP / CLI 工具 / GitHub 仓库**；独立存储于 `~/.agents/skills-vault/.watchlist.json`，不克隆代码到本地、不消耗 Agent 上下文。
  - 支持 **5 档研究状态**（`待研究 / 研究中 / 已评估-推荐 / 持续关注 / 暂不安装`）、标签、可编辑研究笔记、CLI 安装命令一键复制；
  - 支持 **GitHub 只读 API 元信息一键抓取**（Star 数、简介、主语言、最近更新日期，零本地下载）；
  - 支持与本地仓库自动比对亮起「**本地已装**」徽标、一键「**转入本地安装**」、以及一键导出 **JSON / Markdown 研究清单**。

### 2. 全站统一双栏信息架构（v1.3.0 布局统一）
- **左栏一律按「用途 / 性质」分组**：Skills、MCP、Plugins 均按用途自动归类并支持自定义新建分组与手动调整，关注收藏按研究状态分组。
- **右上方一律按「平台 / 载体」横向快筛**：Skills / MCP / Plugins 统一在右侧顶部按 `Antigravity / Codex / Claude`（及 `多端共用`）筛选，彻底消除重复筛选。

### 3. Skills 完整生命周期 & 上下文控制
- **固定仓库 + 三端软链接热同步**：统一存储于 `~/.agents/skills-vault`，独立启停 Antigravity / Codex / Claude；停用 Codex 时同步清理 `~/.agents/skills` 与旧 `~/.codex/skills` 残留软链。
- **GitHub 一键安装 & 来源追踪更新**：支持 `owner/repo`、完整 URL、`tree/<branch>/<subpath>` 与 `.claude/skills` 等深层隐藏目录递归扫描，具备 35 秒超时保护、中途取消与同名覆盖确认；记录来源 commit 支持一键拉取更新。
- **Token 占用估算 & 内嵌预览**：实时估算每个 Skill 及当前启用组合的 Token 消耗，支持卡片内直接预览 `SKILL.md`。
- **场景预设（Profile）**：一键保存与切换不同工作模式的 Skill 启停矩阵（如「前端设计」「逆向调试」「日常轻量」）。
- **安全卸载与转存**：卸载本地 Skill 时支持直接移入废纸篓，或选择「**卸载并转存关注**」保留来源地址。

### 4. MCP 跨端同步 & 多端 Plugins 管理
- **MCP JSON ↔ TOML 跨端一键同步**：强健解析 Antigravity JSON、Claude JSON 与 Codex `config.toml`（支持多行数组、引号表名、内联表），支持单条 MCP 一键同步至其他平台，环境变量值界面脱敏隐藏。
- **Plugins 多端管理 + 一键安装**：统一盘点 Antigravity / Codex / Claude 插件，支持 GitHub / 本地目录 / Codex CLI (`codex plugin add`) 一键安装，以及 Antigravity 与 Codex 插件的开关热启停。

### 5. 环境健康体检 & CLI 依赖检测
- 自动检测并一键修复：悬空软链接、`~/.codex/skills` 旧软链残留、固定仓库无效脏目录、未归档外部实目录；
- 内置 **AI 生态 CLI 就绪检测**（`codex / claude / agy / git / node / npx / uvx / python3`）与 MCP 缺失命令告警；
- 内置目录实时监听（`DispatchSource`）与切回前台自动刷新。

---

## 📦 安装方式 (Installation)

### 方式一：通过 Releases DMG 安装（推荐）
1. 在 [Releases](../../releases) 页面下载最新的 **`Apollo-AgentHub-1.3.0.dmg`**。
2. 双击挂载 DMG 镜像，将 **`Apollo AgentHub.app`** 拖入 **`Applications`** 文件夹。
3. 从「应用程序」或启动台打开即可使用（自动无缝继承原 Apollo SkillHub 的仓库路径与分类配置）。

> **提示**：如首次打开未公证的开源应用提示安全拦截，可在终端运行：
> ```bash
> xattr -cr "/Applications/Apollo AgentHub.app"
> ```

### 方式二：从源码编译 (Build from Source)
模块化纯原生 AppKit + SwiftUI 实现（`Sources/`），无需 Xcode 工程：
```bash
# 1. （可选）重新生成多分辨率图标 AppIcon.icns
swift generate_icon.swift

# 2. 编译 Apple Silicon 原生应用包
./build.sh
```

---

## 🔗 相关开源项目

- **[Apollo-AgentMeter](https://github.com/lingqiushi001-git/Apollo-AgentMeter)** — 原生 macOS 状态栏 AI 剩余额度与重置倒计时实时监控工具

---

## 📄 开源协议 (License)

MIT License © 2026 Apollo
