---
name: code-review
description: This skill should be used when the user asks to "review code", "do a code review", "review my branch", "review MR !1234", "review PR #567", "manage review skills config", "update review skills", or mentions code review related tasks. Routes to config-manager or executor based on user intent.
version: 0.1.0
---

# Code Review

代码审查技能集，包含配置管理和审查执行两个子技能。

## 子技能

- **code-review:config-manager** - 配置管理器，管理 review skills 配置
- **code-review:executor** - 审查执行器，执行代码审查并生成报告

## 工作流程

### Step 1: 识别用户意图

根据用户的输入，判断是配置管理需求还是执行审查需求。

**配置管理关键词**（触发 config-manager）:
- "配置" (config), "管理配置" (manage config)
- "更新 skills" (update skills), "发现 skills" (discover skills)
- "同步 skills" (sync skills), "刷新 skills" (refresh skills)
- "管理预设" (manage presets), "编辑预设" (edit presets)
- "创建预设" (create preset), "删除预设" (delete preset)
- "验证配置" (validate config), "检查配置" (check config)
- "查看配置" (view config), "显示配置" (show config)
- "初始化配置" (init config), "创建配置" (create config)

**执行审查关键词**（触发 executor）:
- "review code", "review my code", "代码审查"
- "review branch", "review {branch} vs {branch}"
- "review MR", "review PR", "review !1234", "review #567"
- "check code quality", "代码质量检查"
- "review entire project", "review all code", "审查整个项目"

### Step 2: 路由到相应技能

**如果是配置管理需求**:
```
使用 Skill tool 调用 code-review:config-manager
```

**如果是执行审查需求**:
```
使用 Skill tool 调用 code-review:executor
```

### Step 3: 执行子技能工作流程

子技能会处理具体的工作流程，此入口只负责路由。

## 使用示例

### 配置管理

**用户输入**: "帮我更新 review skills 配置"
**意图识别**: 配置管理
**路由**: code-review:config-manager

**用户输入**: "查看当前的 review 配置"
**意图识别**: 配置管理
**路由**: code-review:config-manager

**用户输入**: "创建一个新的安全审查预设"
**意图识别**: 配置管理
**路由**: code-review:config-manager

### 执行审查

**用户输入**: "Review my code"
**意图识别**: 执行审查
**路由**: code-review:executor

**用户输入**: "Review feature/auth branch"
**意图识别**: 执行审查
**路由**: code-review:executor

**用户输入**: "Review MR !1234"
**意图识别**: 执行审查
**路由**: code-review:executor

**用户输入**: "代码审查：feature/auth vs dev"
**意图识别**: 执行审查
**路由**: code-review:executor

## 首次使用指南

如果是首次使用 code-review skills：

1. **初始化配置**: 运行 `code-review:config-manager` 初始化配置文件
2. **发现 skills**: 让 config-manager 自动发现可用的 review skills
3. **创建预设**: 根据需要创建自定义预设
4. **执行审查**: 运行 `code-review:executor` 开始代码审查

## 配置文件位置

配置文件支持三级优先级：

- **项目配置**: `.claude/code-review-skills/config.yaml` (最高优先级)
- **用户配置**: `~/.claude/code-review-skills/config.yaml`
- **全局配置**: `~/.config/claude/code-review-skills/config.yaml`

优先级：项目 > 用户 > 全局

## 常见问题

### Q: 配置文件在哪里？
A: 配置文件位于 `.claude/code-review-skills/config.yaml`（项目级）、`~/.claude/code-review-skills/config.yaml`（用户级）或 `~/.config/claude/code-review-skills/config.yaml`（全局级）。

### Q: 如何添加新的 review preset？
A: 运行 `code-review:config-manager`，选择 "管理预设"，然后 "创建新预设"。

### Q: 如何更新 available skills 列表？
A: 运行 `code-review:config-manager`，选择 "发现并更新 skills"。

### Q: 可以直接使用 executor 而不配置吗？
A: 不行，executor 依赖配置文件中的预设。首次使用需要先运行 config-manager 初始化配置。

### Q: 预设中的 skill 不可用怎么办？
A: Executor 会警告您并询问是否跳过该 skill 或取消审查。您可以运行 config-manager 更新 skills 列表。

## 技能关系

```
code-review (主入口)
├── code-review:config-manager (配置管理)
│   ├── 初始化配置文件
│   ├── 自动发现 skills
│   ├── 管理预设配置
│   ├── 查看配置状态
│   └── 验证配置文件
│
└── code-review:executor (审查执行)
    ├── 加载配置文件
    ├── 选择审查预设
    ├── 收集代码内容
    ├── 并行执行审查
    └── 汇总审查结果
```

## 路由决策流程

```python
# 识别用户意图
user_input = "<用户输入>".lower()

# 配置管理关键词
config_keywords = [
    "配置", "config",
    "更新 skill", "update skill", "发现 skill", "discover skill",
    "管理预设", "manage preset", "编辑预设", "edit preset",
    "验证配置", "validate config", "查看配置", "view config",
    "初始化配置", "init config"
]

# 执行审查关键词
review_keywords = [
    "review", "审查", "代码审查",
    "check code quality", "代码质量",
    "mr", "pr", "!1234", "#567", "branch"
]

# 决策
if any(keyword in user_input for keyword in config_keywords):
    # 配置管理
    use Skill tool to invoke "code-review:config-manager"
elif any(keyword in user_input for keyword in review_keywords):
    # 执行审查
    use Skill tool to invoke "code-review:executor"
else:
    # 无法确定意图，询问用户
    use AskUserQuestion to clarify
```

## 注意事项

1. **路由优先级**: 如果用户输入同时匹配配置管理和执行审查关键词，优先执行配置管理（因为配置问题需要先解决）
2. **首次使用**: 首次使用必须先运行 config-manager 初始化配置
3. **配置依赖**: executor 依赖有效的配置文件，如果配置缺失或无效会提示用户
4. **并行执行**: executor 会并行执行多个 skills，建议根据项目大小选择合适的预设
