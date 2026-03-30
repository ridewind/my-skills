# 配置管理详细指南

本文档提供配置管理的详细步骤和参考信息。

## 配置文件位置

配置文件支持三级优先级（级联覆盖）：

| 层级 | 路径 | 用途 |
|------|------|------|
| 全局 | `~/.config/claude/code-review-skills/config.yaml` | 系统级默认 |
| 用户 | `~/.claude/code-review-skills/config.yaml` | 个人默认配置 |
| 项目 | `.claude/code-review-skills/config.yaml` | 特定项目配置 |

**优先级**: 项目 > 用户 > 全局

---

## 初始化配置

### 使用脚本初始化

```bash
# 项目配置（推荐用于特定项目）
./scripts/init-config.sh --project

# 用户配置（推荐用于个人默认配置）
./scripts/init-config.sh --user

# 全局配置（推荐用于系统级默认）
./scripts/init-config.sh --global

# 强制覆盖现有配置
./scripts/init-config.sh --project --force

# 跳过自动发现
./scripts/init-config.sh --project --skip-discover
```

### 手动创建配置

如果脚本不可用，可以手动创建配置文件：

1. 确定配置层级（项目/用户/全局）
2. 创建目录：`mkdir -p .claude/code-review-skills/`
3. 创建配置文件，参考 [配置文件格式](#配置文件格式)

---

## 发现 Review Skills

### 推荐流程（LLM 判断）

使用 LLM 判断可以更准确地识别与 code review 相关的能力。

**Step 1: 收集候选项**

```bash
./scripts/discover-skills.sh --collect-only /tmp/candidates.json
```

脚本会自动：
- 读取配置文件中的 `skills_directories` 字段确定搜索目录
- 扫描所有 SKILL.md 文件（skills）
- 扫描 `~/.claude/plugins/cache/` 下的所有 commands
- 自动排除自身（`code-review-executor`）
- 对相同 ID 的 commands 去重（保留最新版本）

**Step 2: LLM 判断筛选**

读取 JSON 文件，对每个候选项判断是否适合用于 code review 工作流：

**判断标准：**

| 类型 | 描述 | 示例 |
|------|------|------|
| 核心 review 能力 | 直接用于代码审查 | 代码质量审查、安全审计、性能分析、PR/MR 审查 |
| 辅助 review 能力 | 支持 review 过程 | 文档生成、架构分析、调试辅助 |
| 不应包含 | 与代码审查无关 | 代码生成、项目初始化、版本控制操作 |

**Step 3: 更新配置**

```bash
./scripts/discover-skills.sh --from-json /tmp/filtered.json [配置文件路径]
```

### 直接模式（简单场景）

对于简单场景，可以使用直接模式：

```bash
./scripts/discover-skills.sh [配置文件路径]
```

直接模式使用正则表达式过滤，可能不够准确。

### 手动发现（备选方案）

如果脚本执行失败，可以手动操作：

**1. 确定搜索目录**

默认搜索策略：
1. 项目内 skills 目录：`skills/**/SKILL.md`
2. 插件 commands：`~/.claude/plugins/cache/*/commands/*.md`

排除的无关目录：`node_modules/`, `.git/`, `vendor/`, `dist/`, `build/`, `target/`, `__pycache__/`, `.venv/`

**2. 识别 Review 相关能力**

关键词判断：
- review, auditor, reviewer
- security, audit, threat
- test, testing, coverage
- performance, optimization
- quality, cleanup, lint

**3. 分类规则**

| 关键词 | 分类 |
|--------|------|
| security, audit, threat | 安全审计 |
| test, coverage, tdd | 测试+清理 |
| performance, optimization, database | 性能+架构 |
| code-quality, lint, cleanup | 代码质量 |
| 其他 | 代码质量 |

---

## 验证配置

### 使用脚本验证

```bash
./scripts/validate-config.sh [配置文件路径]
```

脚本检查项：
- YAML 语法正确性
- 必需字段存在（metadata, available_skills, presets）
- presets 结构正确
- skill ID 格式有效

### 常见问题

| 问题 | 解决方案 |
|------|----------|
| 配置文件不存在 | 运行 `init-config.sh` 初始化 |
| YAML 语法错误 | 运行 `validate-config.sh` 检查错误位置 |
| Skill 不存在 | 运行 `discover-skills.sh` 更新可用 skills |
| 权限问题 | 检查目录权限，手动创建目录 |

---

## 管理预设配置

### 显示当前预设

读取配置文件的 `presets` 部分，向用户展示：

```
当前预设配置：

1. 快速审查 (2 个 skills)
   - code-review:code-review
   - codebase-cleanup:code-reviewer

2. 全面审查 (5 个 skills)
   - code-review:code-review
   - security-scanning:security-auditor
   ...
```

### 创建新预设

1. 询问预设名称和描述
2. 显示所有可用的 skills（按分类分组）
3. 让用户选择 skills
4. 将新预设添加到配置文件

### 编辑预设

1. 让用户选择要编辑的预设
2. 显示当前包含的 skills
3. 询问要添加/删除哪些 skills
4. 更新配置文件

### 删除预设

1. 让用户选择要删除的预设
2. 确认删除操作
3. 从配置文件中移除

---

## 查看配置状态

### 配置文件路径

按优先级检查三个层级：

```
配置文件状态：

✓ 项目配置: .claude/code-review-skills/config.yaml
✓ 用户配置: ~/.claude/code-review-skills/config.yaml
- 全局配置: 不存在

当前生效的配置将合并上述文件（项目配置优先级最高）
```

### 可用 Skills

按分类分组显示：

```
可用 skills (共 15 个):

代码质量 (6):
  - code-review:code-review - 基础代码审查
  - codebase-cleanup:code-reviewer - 代码清理审查
  ...

安全审计 (4):
  - security-scanning:security-auditor - 安全审计专家
  ...
```

### 合并结果

如果存在多层级配置：

```bash
./scripts/merge-configs.sh [输出路径]
```

合并规则：
- `available_skills` 取并集
- `presets` 按名称覆盖（高优先级覆盖低优先级）

---

## 配置文件格式

```yaml
metadata:
  version: "0.2.0"
  last_updated: "2025-01-15"
  auto_sync: true

# Skills 搜索目录配置
# 支持相对路径（相对于配置文件所在目录）和绝对路径
skills_directories:
  - "skills"           # 默认：项目内的 skills 目录
  # - ".skills"          # 可选：隐藏的 skills 目录
  # - "../other-skills"  # 可选：其他项目的 skills 目录
  # - "~/.claude/skills" # 可选：用户级 skills 目录

# 可用的 code review skills 和 commands
# type 字段标识能力类型: skill 或 command
available_skills:
  - id: "code-review:code-review"
    name: "code-review:code-review"
    type: "command"
    category: "安全审计"
    description: "检查代码质量问题"
    tags: ["review", "security"]
    recommended_for: ["所有项目"]

  - id: "pr-review-toolkit:review-pr"
    name: "pr-review-toolkit:review-pr"
    type: "command"
    category: "测试+清理"
    description: "PR 审查工具"
    tags: ["review", "pr"]
    recommended_for: ["所有项目"]

presets:
  - name: "快速审查"
    description: "轻量级快速审查"
    skills:
      - "code-review:code-review"

  - name: "全面审查"
    description: "包含所有维度的深度审查"
    skills:
      - "code-review:code-review"
      - "security-scanning:security-auditor"
      - "application-performance:performance-engineer"
```

---

## 注意事项

1. **保留用户编辑**: 更新 `available_skills` 时，始终保留用户的 `presets` 配置
2. **配置合并**: 多层级配置时，`available_skills` 取并集，`presets` 按名称覆盖
3. **YAML 格式**: 编辑配置文件时注意 YAML 缩进和格式
4. **skill ID**: skill ID 使用 `skill:name` 格式，确保与实际 skill 名称一致
5. **自身排除**: 发现过程中会自动排除 `code-review-executor`，避免循环依赖