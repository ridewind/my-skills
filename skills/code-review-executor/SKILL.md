---
name: code-review-executor
description: This skill should be used when the user asks to "review code", "do a code review", "review my branch", "review MR !1234", "review PR #567", "review feature/auth branch", "review feature/auth vs dev", "check code quality", "manage review skills config", "update review skills", "discover review skills", or wants to execute code review using configured skill presets.
---

# Code Review Executor

执行代码审查的完整解决方案：配置管理、审查执行、结果汇总。

## Quick Reference

**详细参考**:
- 配置管理: `references/configuration-guide.md`
- 问题分类: `references/issue-categories.md`
- 报告格式: `references/report-formatting.md`
- 子代理协调: `references/subagent-coordination.md`
- 快速参考: `references/quick-reference.md`
- 代码模板: `references/code-templates.md`

### 8-Step Workflow

| Step | Action |
|------|--------|
| 0 | Debug Mode Detection |
| 1 | Load & Validate Config |
| 2 | Determine Review Scope |
| 3 | Create Working Directory |
| 4 | Select Review Preset |
| 5 | Collect Code Content |
| 6 | Parallel Execution |
| 7 | Consolidate Results |

### Key Scripts

| 脚本 | 用途 |
|------|------|
| `scripts/collect-review-data.sh` | 数据收集 |
| `scripts/discover-skills.sh` | 技能发现 |
| `scripts/init-config.sh` | 配置初始化 |
| `scripts/validate-config.sh` | 配置验证 |
| `scripts/merge-configs.sh` | 配置合并 |
| `scripts/find-merge-base.sh` | 查找合并基准 |

---

## 文件写入规范

**重要**: 所有文件写入操作必须使用 **Write 工具**，而不是通过 Bash 工具执行 `cat >` 等 shell 命令。

**Write 工具的使用场景**:
- 保存 JSON 配置文件（code-context.json, commits.json, branch-info.json）
- 保存 Markdown 报告（DEBUG-SESSION.md, 综合报告, skill 报告）
- 任何需要创建或修改文件的场景

**Bash 工具的使用场景**:
- 查询信息（git log, git diff, ls）
- 移动/复制文件
- 创建目录
- 执行 shell 脚本

---

## 配置管理（前置步骤）

在执行代码审查前，需要确保配置已初始化。

### 配置文件位置

配置文件支持三级优先级：

| 层级 | 路径 | 用途 |
|------|------|------|
| 项目 | `.claude/code-review-skills/config.yaml` | 特定项目配置 |
| 用户 | `~/.claude/code-review-skills/config.yaml` | 个人默认配置 |
| 全局 | `~/.config/claude/code-review-skills/config.yaml` | 系统级默认 |

**优先级**: 项目 > 用户 > 全局

### 快速配置操作

#### 初始化配置

```bash
# 项目配置（推荐）
./scripts/init-config.sh --project

# 用户配置
./scripts/init-config.sh --user

# 全局配置
./scripts/init-config.sh --global
```

选项：`--force` 强制覆盖，`--skip-discover` 跳过自动发现

#### 发现 Review Skills

**推荐流程（LLM 判断）**:
```bash
# 1. 收集候选项
./scripts/discover-skills.sh --collect-only /tmp/candidates.json

# 2. LLM 判断筛选（在对话中完成）

# 3. 更新配置
./scripts/discover-skills.sh --from-json /tmp/filtered.json
```

**直接模式**:
```bash
./scripts/discover-skills.sh [配置文件路径]
```

#### 验证配置

```bash
./scripts/validate-config.sh [配置文件路径]
```

#### 查看配置状态

读取配置文件，显示：
- 配置文件路径
- 可用 skills（按分类分组）
- 预设配置

**详细步骤**: 参考 `references/configuration-guide.md`

---

## 能力类型

支持两种类型的 review 能力：

| 类型 | 定义位置 | 调用方式 |
|------|----------|----------|
| **skill** | SKILL.md 文件 | Task 工具，subagent_type |
| **command** | 插件 commands/*.md | Skill 工具调用 |

**自动排除**: 发现过程中会自动排除自身（`code-review-executor`），避免循环依赖。

---

## Workflow

### Step 0: Debug Mode Detection (Optional)

**启用方式**:
1. 用户输入包含关键词（`debug`, `verbose`, `调试`, `详细`, `--debug`, `-v`）
2. 交互式确认时选择 "启用调试"

**记录内容**: 检查点、决策点、用户选择、subagent 状态、时间戳

**输出**: 使用 Write 工具保存到 `DEBUG-SESSION.md`

---

### Step 1: 加载并验证配置

#### 1.1 查找配置文件

按优先级查找（项目 > 用户 > 全局）。

#### 1.2 检查配置是否存在

**如果配置文件不存在**:
```
未找到 Code Review 配置文件。

需要先配置 review skills。请：
1. 运行初始化配置
2. 或选择下方快速初始化

[快速初始化] [手动配置] [取消]
```

#### 1.3 合并多层级配置

如果存在多层级配置，运行 `scripts/merge-configs.sh` 合并。

合并规则：
- `available_skills`: 取并集，去重
- `presets`: 按名称覆盖（项目 > 用户 > 全局）

#### 1.4 验证配置

运行 `scripts/validate-config.sh` 验证配置文件。

检查：YAML 语法、必需字段、Preset 结构、Skill ID 格式

---

### Step 2: 确定审查范围

**审查类型**:
- **分支**: 单个分支（如 `feature/auth`）
- **分支对比**: 分支 A vs 分支 B（如 `feature/auth` vs `dev`）
- **MR/PR**: 通过编号或 URL 指定
- **项目**: Monorepo 子项目
- **全项目**: 整个代码库

**所需信息**: 分支名称、MR/PR 编号或 URL、项目路径、仓库 URL

---

### Step 3: 建立工作目录

**目录命名规范**: `{review_name}-{YYYYMMDD}-{sequence}`

**生成唯一工作目录**:
```bash
DATE=$(date +%Y%m%d)
BASE_DIR="{review_name}-${DATE}"
EXISTING=$(ls -d reviews/${BASE_DIR}-* 2>/dev/null | wc -l)
SEQUENCE=$((EXISTING + 1))
WORKING_DIR="${BASE_DIR}-${SEQUENCE}"
```

**目录结构**:
```
reviews/{review_name}-{YYYYMMDD}-{sequence}/
├── code-context.json
├── diff.patch
├── commits.json
├── branch-info.json
├── DEBUG-SESSION.md
├── {review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md
└── reports/
    ├── skill1-report.md
    └── skill2-report.md
```

---

### Step 4: 选择审查预设

#### 4.1 读取预设配置

使用 Read 工具读取配置文件中的 `presets` 部分。

#### 4.2 显示可用预设

```
可用预设配置：

1. 快速审查 (2 个 skills)
   描述: 轻量级快速审查，适用于日常开发
   包含: code-review:code-review, codebase-cleanup:code-reviewer

2. 全面审查 (5 个 skills)
   描述: 包含所有维度的深度审查
   包含: code-review:code-review, security-scanning:security-auditor, ...
```

#### 4.3 用户选择预设

使用 AskUserQuestion 让用户选择。如果只有一个预设，跳过选择。

#### 4.4 验证 Skill 可用性

检查配置中引用的所有 skill 都可用：
- **skill** 类型：检查 SKILL.md 文件是否存在
- **command** 类型：检查命令文件是否存在于插件缓存中

**处理缺失 Skill**: 提示用户选择跳过、取消或尝试安装

---

### Step 5: 收集代码内容

#### 5.1 优先使用脚本

```bash
bash scripts/collect-review-data.sh -s <source_branch> -t <target_branch> -o <working_directory>
```

脚本生成：code-context.json, diff.patch, commits.json, branch-info.json

#### 5.2 检查收集结果

验证所有文件存在。

#### 5.3 手动回退方案（脚本失败时）

使用 Bash 工具获取 git 信息，使用 Write 工具保存。

#### 5.4 向用户确认

使用 AskUserQuestion 呈现收集的信息，等待用户确认。

---

### Step 6: 并行执行审查

#### 6.1 准备 Subagent 任务

对于选中的预设中的每个能力：
- 从 `available_skills` 获取详细信息
- 检查 `type` 字段确定能力类型
- 准备能力专用的 prompt

#### 6.2 启动并行 Subagents

**重要**: 在单个消息中启动所有 subagents 以实现真正的并行执行。

**示例 Task 调用**:
```xml
<Task subagent_type="general-purpose"
      prompt="使用 code-review:code-review skill 审查以下代码..."
      run_in_background="true"
      description="Review code with code-review skill">

<Task subagent_type="general-purpose"
      prompt="使用 Skill 工具调用 pr-review-toolkit:review-pr 命令执行 PR 审查..."
      run_in_background="true"
      description="Review with review-pr command">
```

#### 6.3 等待 Subagents 完成

使用 TaskOutput 工具等待完成。

**超时设置**:
| 变更大小 | 超时时间 |
|----------|----------|
| 小型 (<500 行) | 1 分钟 |
| 中型 (500-2000 行) | 3 分钟 |
| 大型 (2000-10000 行) | 5 分钟 |
| 超大型 (>10000 行) | 10 分钟 |

#### 6.4 处理失败的任务

记录失败信息，继续等待其他 subagents，在最终报告中标注。

---

### Step 7: 汇总审查结果

#### 7.1 读取所有报告

使用 Glob 工具获取报告文件列表，使用 Read 工具读取内容。

#### 7.2 解析报告内容

从每个报告中提取问题列表，标记问题来源 skill。

#### 7.3 去重问题

按文件路径、行号范围、问题类型去重，合并发现者信息。

#### 7.4 按严重程度分类

| 等级 | 描述 |
|------|------|
| **Critical** | 必须修复的安全问题或严重 bug |
| **High** | 应该修复的重要问题 |
| **Medium** | 建议修复的一般问题 |
| **Low** | 可选改进的问题 |
| **Info** | 信息性建议 |

#### 7.5 生成综合报告

使用 Write 工具生成 `{review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md`

**报告格式**: 参考 `references/report-formatting.md`

---

## Debug 输出

当 Debug Mode 启用时，在每个步骤记录详细日志：

```
🔍 DEBUG [Step 1/7]: 加载并验证配置
🔍 DEBUG [Step 2/7]: 确定审查范围 - 分支对比
🔍 DEBUG [Step 3/7]: 建立工作目录 - mr557-20260130-1
🔍 DEBUG [Checkpoint 1]: 收集代码内容完成，等待用户确认
...
```

---

## 错误处理

| 错误类型 | 处理方式 |
|----------|----------|
| 配置文件缺失 | 提示初始化配置，提供快速初始化选项 |
| 配置验证失败 | 显示错误详情，建议修复方法 |
| Preset 不存在 | 列出可用预设，让用户重新选择 |
| Skill/Command 不可用 | 警告用户，询问跳过或取消 |
| Subagent 执行失败 | 记录失败详情，继续执行其他 subagents |

---

## 配置文件格式

```yaml
metadata:
  version: "0.2.0"
  last_updated: "2026-03-30"
  auto_sync: true

skills_directories:
  - "skills"

available_skills:
  - id: "code-review:code-review"
    name: "code-review:code-review"
    type: "command"
    category: "代码质量"
    description: "Code review a pull request"
    tags: ["review", "quality"]
    recommended_for: ["所有项目"]

presets:
  - name: "快速审查"
    description: "轻量级快速审查"
    skills:
      - "code-review:code-review"
```

**完整示例**: `examples/sample-config.yaml`

---

## 注意事项

1. **配置优先级**: 始终先检查项目级配置，然后用户级，最后全局级
2. **能力类型**: 根据配置中的 `type` 字段选择正确的调用方式
3. **并行执行**: 所有 subagents 必须在单个消息中启动以实现真正的并行
4. **用户确认**: 在启动 subagents 前必须获得用户确认
5. **文件命名**: 工作目录和报告文件必须包含日期和序列号
6. **错误恢复**: 如果某个 subagent 失败，继续执行其他 subagents 并在报告中标注
7. **保留用户编辑**: 更新 `available_skills` 时，始终保留用户的 `presets` 配置